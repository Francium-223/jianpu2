# -*- coding: utf-8 -*-
"""爬 jianpu.cn(歌谱简谱网) 的曲谱图, 用于补充"流行歌" —— 库里最大的来源(3,215 首)。

站点是 GBK 编码。入口:
  * 歌手页 `/g/xx/yyyy.htm` —— 列出该歌手**全部**曲谱(这是扩量的主力入口);
  * 曲谱页 `/pu/NN/NNNNNN.htm` —— 含图片 URL(单引号)与该曲的歌手链接。

判据(2026-10-06 实测复核, 每条的"为什么"写在各处注释里):
  * 谱图地址: 老页 `/img/...`, 2025 起新页 `/img9/...` —— 旧写法 `^/img/` 对新页 **0 命中**,
    于是每首歌都"页面里没有图"地静默跳过, 退出码还是 0(见 `IMG_RE`);
  * 歌手链接: 还有 `/g/BE/BEYOND.htm`、`/g/SI/SINGnvtuan.htm` 这种**大写**形态, 原正则没带 `re.I`;
  * 曲名: 详情页 `<title>` 从 2025 起把**歌手**追在曲名后面 ⇒ 老写法把歌手写进目录名(见 `song_title`);
  * 站内 id -> 页址: 目录就是 id 的**前两位**, 原写法"去掉末四位"对 5 位 id 一律 404(见 `sid_url`);
  * 谱图后缀: 站点上 `.gif` 与 `.jpg` 都有 ⇒ 按**魔数**定扩展名, 不抄 URL 后缀(见 `ext_of`)。

策略: 种子曲谱页 -> 歌手页 -> 该歌手全部曲谱 -> 下载图片; 新歌手、相关曲谱继续入队(BFS)。

2026-09-25 夜间改造:
  * **断点续爬**: 访问过的曲谱/歌手页与两条队列写进状态文件(默认 `_analysis/crawl_state_jianpucn.json`),
    重启不重抓(以前每次从头来过, 只靠"文件已存在就跳过"省下载);
  * **种子换成语料里 source=jianpucn-* 的页面** —— 保证是"我们要的那类歌", 再由歌手页铺开;
  * 图库统一落**工作区** `images-prep/`(`JIANPU_IMAGES` 可覆盖; 以前写相对路径, 靠 jianpu2/images-prep
    那个软链才对上, 现在显式写清楚)。

用法:
    python3 tools/crawl_jianpucn.py 1500 --max-artists 300        # 抓 1500 首, 最多铺 300 个歌手
    python3 tools/crawl_jianpucn.py 50 --seeds 438812 150657      # 只用这些曲谱 id 当种子
"""
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
# 把自己所在的 tools/ 也放进 sys.path(`guard`/`jp_root`/`corpus_index` 都在这里) ——
# 原来的写法只在 `py tools/crawl_jianpucn.py` 这种跑法下才 import 得到, 换个 cwd 就崩。
# 工作区目录那条保持原样。
sys_path_tools = os.path.dirname(HERE)
for _p in (HERE, sys_path_tools):
    if _p not in sys.path:
        sys.path.insert(0, _p)

# --help 保护: 本脚本没有 argparse, 万一被当冒烟测试跑起来会**真的开始下载** —— 直接打文档退出。
# 2026-10-06 修: 这一段原来在 `from jp_root import images_root` **之后**, 而 `jp_root` 自己也有
# `guard_help(__doc__)` —— 于是 `--help` 打出来的是 jp_root 的文档, 不是本脚本的用法。
# 挪到所有项目内 import 之前, 谁先拦谁说了算(与 `crawl_jianpucn_by_title.py` 那处修法同口径)。
from guard import guard_help        # noqa: E402
guard_help(__doc__)

from jp_root import images_root     # noqa: E402

ROOT = os.path.dirname(HERE)                        # jianpu2
WS = os.path.dirname(ROOT)                          # 工作区
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
IMG_ROOT = images_root()
OUT = os.path.join(IMG_ROOT, "jianpucn-pop")
STATE = os.path.join(WS, "_analysis", "crawl_state_jianpucn.json")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
BASE = "http://www.jianpu.cn"


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=25) as r:
        raw = r.read()
    return raw if binary else raw.decode("gbk", errors="replace")


def safe(name):
    name = re.sub(r"&nbsp;|\s+", " ", name).strip()
    name = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", name)
    return name[:60] or "untitled"


def ext_of(data):
    """按**魔数**定扩展名 —— 站点上有 .gif 老页谱图, 一律写 `.jpg` 会存出假后缀。

    与 `crawl_jianpucn2.py` / `crawl_jianpucn_by_title.py` 的 `ext_of` 同一口径。
    """
    if data[:4] == b"\x89PNG":
        return ".png"
    if data[:3] == b"GIF":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


def song_title(html, sid):
    """曲名 —— 只认 `<h1>`(实测 `推车歌` / `Amammani` / `Amani （ C调指法原版编配）`)。

    2026-10-06 实测: 详情页 `<title>` 从 2025 起把**歌手**追在曲名后面
    (`推车歌 焦阳  歌谱简谱网`、`Amammani BEYOND  歌谱简谱网`、`Amani （ C调指法原版编配） Beyond`),
    而 `<h1>` 一直只有曲名。老写法只砍站点后缀 ⇒ 歌手一路进目录名, 再漏进转写队列的"曲名"列;
    更要紧的是**语料判重会因此失效**(归一化后 `推车歌焦阳` ≠ 语料里的 `推车歌`, 而三个字又够不上
    `corpus_index.same()` 那条">=4 字才认包含"的规则), 于是同一首歌反复重抓。
    `tools/harvest_artists.py` 也是按"`<曲名> <歌手> 歌谱简谱网`"这个新排法抽歌手的, 可互相印证。
    """
    m = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
    raw = m.group(1) if m else ""
    if not raw.strip():
        mt = re.search(r"<title>(.*?)</title>", html, re.S)
        raw = re.sub(r"\s*歌谱简谱网\s*$", "", mt.group(1)).strip() if mt else ""
    raw = re.sub(r"<[^>]+>", "", raw)                 # h1 里偶尔套 <a>/<font>
    t = safe(raw)
    return t if t != "untitled" else "untitled-%s" % sid     # 取不到就带上 id, 免得十几首歌挤一个目录


def sid_url(sid):
    """站内 id -> 曲谱页 URL。目录就是 id 的**前两位**。

    2026-10-06 实测(1~6 位 id 各取样本, 全部 200 且 h1 对得上):
        /pu/9/9.htm · /pu/13/13.htm · /pu/78/784.htm · /pu/35/3588.htm
        /pu/37/37075.htm · /pu/90/90797.htm · /pu/19/194129.htm
    而原写法 `sid[:len(sid) - 4] or sid[:2]` 对 5 位 id 给出 `/pu/9/90797.htm` —— **HTTP 404**。
    图库里 5 位 id 有 4056 个(共 10410 个目录), 也就是约 39% 的种子 URL 一直在 404 之后被
    静默 `continue` 掉。仓库里另外两处(独立写的)也是"前两位": `harvest_page_meta.py:161`、
    `verify_source_urls.py:182`。注意 id 只有 1~2 位时"前两位"照样正确(取不满就是全部)。
    """
    return "%s/pu/%s/%s.htm" % (BASE, sid[:2], sid)


# 谱图地址(2026-10-06 实测): 老页形如 `/img/8f/bc/<hash>.gif`、`/img/9/da/<hash>.jpg`
# (第一级目录还有单字符的, 如 `/img/d/27/…`、`/img/3/11/…`); 2025 起的新页形如
# `/img9/2/kv/<hash>.jpg`。所以第一级目录要写成 `\d*` —— **只写 `/img/` 匹配不到 `/img9/`**,
# 新页一张都取不到, 而脚本会当成"这首歌页面里没有图"静静跳过(退出码仍是 0)。
# 口径与 `crawl_jianpucn2.py` / `crawl_jianpucn_by_title.py` 一致; `tools/check_jianpucn_filter.py`
# 会用 ast 从本文件抠出这条正则, 并断言它能匹配 `/img9/` 形态。
IMG_RE = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)


def img_of(html):
    """谱图: 单双引号都要认(站点用单引号), 排除 logo/广告。"""
    return [x for x in IMG_RE.findall(html) if "logo" not in x.lower()]


_IMG_EXT = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)


def _has_image(d, idx):
    """目录里第 idx 张图在不在 —— **认所有图片后缀**。

    老写法按 URL 后缀拼死文件名(如 `001.gif`)再 `os.path.exists`, 同一个 id 的图床换个后缀
    (实测老页是 `.gif`、新页是 `.jpg`)就会被判成"没下过"而白重下一遍。
    """
    if not os.path.isdir(d):
        return False
    head = "00%d." % idx
    return any(f.startswith(head) and _IMG_EXT.search(f) for f in os.listdir(d))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本爬虫原来只按"图文件在不在"判已抓过, 而图文件与语料是两套账: 同一首歌从别的源抓过、
    或转过写之后目录被挪过的, 都会再抓一遍再进一次转写队列(2026-10-04 实测那一轮 1764 条
    队列几乎全是重复, 净增 1 首)。曲名/站内 id 命中语料就整条跳过。
    导入失败照常抓 —— 宁可多下, 不要因为索引坏了整轮空转。
    """
    try:
        if HERE not in sys.path:
            sys.path.insert(0, HERE)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None


def corpus_seed_pages(limit):
    """语料里 source=jianpucn-<id> 的页面当种子 —— 保证是"我们要的那类歌"。"""
    out, p = [], os.path.join(DB, "data.jsonl")
    if not os.path.isfile(p):
        return out
    for ln in io.open(p, encoding="utf-8"):
        r = json.loads(ln)
        for s in (r.get("source") or []):
            if s.startswith("jianpucn-"):
                sid = s.split("-", 1)[1]
                out.append(sid_url(sid))              # 2026-10-06: 原来在这里"去掉末四位"拼目录(5 位 id 全 404)
                break
        if len(out) >= limit:
            break
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    args = sys.argv[1:]
    target = int(args[0]) if args and args[0].isdigit() else 300
    max_artists = 300
    if "--max-artists" in args:
        max_artists = int(args[args.index("--max-artists") + 1])
    seeds = []
    if "--seeds" in args:
        for sid in args[args.index("--seeds") + 1:]:
            if not sid.isdigit():
                break
            seeds.append(sid_url(sid))                # 同上: 目录取 id 前两位
    if not seeds:
        seeds = corpus_seed_pages(300) or ["%s/pu/43/438812.htm" % BASE]

    os.makedirs(OUT, exist_ok=True)
    st = {"songs_seen": [], "artists_seen": [], "song_q": [], "artist_q": [], "done": 0}
    if os.path.isfile(STATE):
        try:
            st.update(json.load(io.open(STATE, encoding="utf-8")))
        except Exception:
            pass
    song_q = list(dict.fromkeys(list(st.get("song_q") or []) + seeds))
    artist_q = list(st.get("artist_q") or [])
    seen_songs = set(st.get("songs_seen") or [])
    seen_artists = set(st.get("artists_seen") or [])
    done = int(st.get("done") or 0)
    print(f"目标 {target} 首(本次) · 队列: 曲谱 {len(song_q)} / 歌手 {len(artist_q)} · "
          f"已访问 曲谱 {len(seen_songs)} / 歌手 {len(seen_artists)} · 输出 {OUT}", flush=True)

    def save():
        json.dump({"songs_seen": sorted(seen_songs)[-40000:], "artists_seen": sorted(seen_artists)[-5000:],
                   "song_q": song_q[:8000], "artist_q": artist_q[:2000], "done": done},
                  io.open(STATE, "w", encoding="utf-8"), ensure_ascii=False)

    got = 0
    fails = {}                     # 失败/空手的原因 -> 次数(跑完打一行, 别再"悄悄收 0 张图"还退出 0)
    _ci = _corpus_index()
    skipped = _ci.SkipCounter() if _ci is not None else None
    while (song_q or artist_q) and got < target:
        if song_q:
            url = song_q.pop(0)
            if url in seen_songs:
                continue
            seen_songs.add(url)
            try:
                html = fetch(url)
            except Exception as e:
                fails["曲谱页取不到: " + type(e).__name__] = fails.get("曲谱页取不到: " + type(e).__name__, 0) + 1
                continue
            sid = re.search(r"/(\d+)\.htm", url).group(1)
            title = song_title(html, sid)        # 2026-10-06: 改认 <h1>, 别把 <title> 里的歌手带进目录名
            # 语料里已有 -> 跳过(站内 id 或曲名), 不建目录、不下图
            if _ci is not None:
                r = _ci.skip_reason("jianpucn", sid, title)
                if r:
                    skipped.count(r)
                    if r == "title":
                        skipped.note_title_skip(title[:44])
                    continue
            imgs = img_of(html)
            if not imgs:
                fails["页面里没匹配到谱图(/img\\d*/)"] = fails.get("页面里没匹配到谱图(/img\\d*/)", 0) + 1
            if imgs:
                d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
                os.makedirs(d, exist_ok=True)
                ok = 0
                for i, iu in enumerate(imgs[:3]):
                    if _has_image(d, i + 1):
                        ok += 1
                        continue
                    try:
                        data = fetch(BASE + iu, binary=True)
                        if len(data) < 8000:
                            # 站点上的占位/广告图只有 1~3KB; 谱图实测 130KB 上下
                            continue
                        # 后缀按魔数定(不抄 URL 后缀): 老页的谱图多是 .gif, 新页是 .jpg
                        with open(os.path.join(d, "00%d%s" % (i + 1, ext_of(data))), "wb") as g:
                            g.write(data)
                        ok += 1
                    except Exception as e:
                        fails["图片下载失败: " + type(e).__name__] = \
                            fails.get("图片下载失败: " + type(e).__name__, 0) + 1
                    time.sleep(1.0)              # 本次纪律: 限速 >=1 秒/请求(原来 0.3 秒)
                if ok:
                    got += 1
                    done += 1
                    print(f"  [{got}/{target}] {title[:30]:<32} {ok} 图", flush=True)
            # 歌手链接(2026-10-06 实测): 小写/大写/混合三种都有 —— `/g/ji/jiaoyang.htm`、
            # `/g/BE/BEYOND.htm`、`/g/Be/Beyond.htm`、`/g/SI/SINGnvtuan.htm`。原正则没带 `re.I`,
            # 大写那几个(BEYOND 这类大牌)会被静静漏掉, 12 条实测样本里就有 1 条漏。
            for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", html, re.I):
                full = BASE + a
                if (full not in seen_artists and full not in artist_q
                        and len(seen_artists) + len(artist_q) < max_artists):
                    artist_q.append(full)
            for s in re.findall(r"href='(/pu/\d+/\d+\.htm)'", html):
                full = BASE + s
                if full not in seen_songs and full not in song_q:
                    song_q.append(full)
            time.sleep(1.0)                  # 本次纪律: 限速 >=1 秒/请求(原来 0.4 秒)
        else:
            aurl = artist_q.pop(0)
            if aurl in seen_artists:
                continue
            seen_artists.add(aurl)
            try:
                html = fetch(aurl)
            except Exception as e:
                fails["歌手页取不到: " + type(e).__name__] = fails.get("歌手页取不到: " + type(e).__name__, 0) + 1
                continue
            cnt = 0
            for s in re.findall(r"href='(/pu/\d+/\d+\.htm)'", html):
                full = BASE + s
                if full not in seen_songs and full not in song_q:
                    song_q.append(full)
                    cnt += 1
            print(f"  [歌手页] {aurl.split('/')[-1]:<16} 新增 {cnt} 曲", flush=True)
            time.sleep(1.0)                  # 本次纪律: 限速 >=1 秒/请求(原来 0.4 秒)
        if len(seen_songs) % 20 == 0:
            save()
    save()
    print(f"\n本次新下 {got} 首(累计 {done}); 已访问 曲谱 {len(seen_songs)} / 歌手 {len(seen_artists)}; "
          f"队列还剩 曲谱 {len(song_q)} / 歌手 {len(artist_q)}", flush=True)
    if fails:
        print("空手/失败统计(以前这些是静默 `except: continue`, 所以只会看到\"新下 0 首\"):")
        for k, v in sorted(fails.items(), key=lambda kv: -kv[1]):
            print("   %-34s %d" % (k, v))
    if skipped is not None:
        print(skipped.summary())
    return 0


if __name__ == "__main__":
    sys.exit(main())
