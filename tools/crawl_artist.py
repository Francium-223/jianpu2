# -*- coding: utf-8 -*-
"""爬指定歌手页的所有曲谱(jianpu.cn)。

用法: py tools/crawl_artist.py <歌手页URL> [目标数]
       py tools/crawl_artist.py http://www.jianpu.cn/g/zh/zhoujielun.htm 600

为什么需要它: crawl_pop.py 是顺着"相关链接"发现歌手的, 会漏掉大牌
(实测周杰伦 1257 首一首都没爬到)。拿到歌手页 URL 就能整页抓。
输出: images-prep/<歌手拼音>/<标题>__jianpucn-<id>/
"""
import os, re, sys, time, urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from crawl_limits import pages       # noqa: E402  谱图页数上限: 默认不截断(见 tools/crawl_limits.py)
sys.stdout.reconfigure(encoding="utf-8")

URL = sys.argv[1] if len(sys.argv) > 1 else "http://www.jianpu.cn/g/zh/zhoujielun.htm"
TARGET = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 400
slug = re.sub(r"[^a-z0-9]", "", os.path.basename(URL).replace(".htm", "")) or "artist"
OUT = os.path.join("images-prep", f"jianpucn-{slug}")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


# 本文件所在目录(tools/) —— 取共用模块 `corpus_index` 用(不依赖 cwd)
_TOOLS = os.path.dirname(os.path.abspath(__file__))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本脚本原来那句"已存在则跳过(按 id 判)"是 `any(sid in name for name in os.listdir(OUT))` ——
    拿 sid 去**子串**匹配目录名, 既会被别的 id 里的数字蹭到, 也与语料无关。现在改成语料判据:
    站内 id 或曲名在语料里就跳过(2026-10-04 实测: 只按目录判会反复重抓语料里早有的曲子)。
    导入失败照常抓 —— 宁可多下, 不要因为索引坏了整轮空转。
    """
    try:
        if _TOOLS not in sys.path:
            sys.path.insert(0, _TOOLS)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None


os.makedirs(OUT, exist_ok=True)
print(f"歌手页: {URL}\n输出目录: {OUT}")
try:
    html = fetch(URL)
except Exception as e:
    print("歌手页取失败:", e); sys.exit(1)
links = list(dict.fromkeys(re.findall(r"href='(/pu/\d+/\d+\.htm)'", html)))
print(f"该页曲谱链接: {len(links)} 个, 目标抓 {TARGET}")

done = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
for path in links:
    if done >= TARGET:
        break
    sid = re.search(r"/(\d+)\.htm", path).group(1)
    # 语料里已有 -> 跳过(站内 id 或曲名); 比原来那句 `any(sid in name ...)` 的子串匹配准
    if _ci is not None:
        r = _ci.skip_reason("jianpucn", sid, "")
        if r:
            skipped.count(r)
            done += 1
            continue
    try:
        h = fetch("http://www.jianpu.cn" + path)
    except Exception:
        continue
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", h, re.S)
    title = safe(m1.group(1)) if m1 else f"untitled-{sid}"
    if _ci is not None:
        r = _ci.skip_reason("", "", title)
        if r:
            skipped.count(r)
            skipped.note_title_skip(title[:44])
            done += 1
            continue
    # 谱图地址(2026-10-06 实测): 老页 `/img/8f/bc/<hash>.gif`, 2025 起新页 `/img9/2/kv/<hash>.jpg`
    # —— 旧写法 `/img/` 对新页 **0 命中**, 于是整轮"下载 0 张"却退出 0。`\d*` 两种都认。
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", h, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        continue
    dd = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    # 保持原有的"目录已在"幂等性(与语料判据不冲突: 目录在 = 这一首下过了)
    # ⚠ 但要**忽略 `.part`**: 原子落盘被杀进程时只留 `00N.jpg.part`, 那不是成品图; 不排除的话
    # 这种目录会被当成"下过了", 那一页永远补不回来。
    if os.path.isdir(dd) and [x for x in os.listdir(dd) if not x.endswith(".part")]:
        done += 1
        continue
    os.makedirs(dd, exist_ok=True)
    ok = 0
    # 2026-10-06 修: 原来写死 `imgs[:2]` —— 实测详情页最多有 6 张(《93海阔天空》), 只存 2 张
    # 会让后面几页**永远下不到**。默认全部(可用 `JIANPU_MAX_PAGES` 给上限)。
    for i, iu in enumerate(pages(imgs)):
        try:
            req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
            # 原子落盘(.part -> os.replace): 抓取可能被磁盘硬止损直接杀进程, 直接写目标名会留一张
            # 截断图, 而续爬只按"文件名在不在"判 ⇒ 半张图被当成品收下、永不重下(口径同 crawl_jianpucn.py)。
            fn = os.path.join(dd, f"00{i+1}.jpg")
            part = fn + ".part"
            with urllib.request.urlopen(req, timeout=25) as r, open(part, "wb") as g:
                g.write(r.read())
            os.replace(part, fn)
            ok += 1
        except Exception:
            pass
        time.sleep(0.2)
    if ok:
        done += 1
        if done % 25 == 0:
            print(f"  [{done}/{TARGET}] {title[:36]}", flush=True)
    time.sleep(0.25)
print(f"\n完成: {done} 首 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
