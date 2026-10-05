# -*- coding: utf-8 -*-
"""按曲名在 jianpu.cn 的分类目录里"扫目录 -> 只下命中的那几张"。

为什么这么做: jianpu.cn 没有可用的关键词搜索(/search 是空壳), 但曲谱按**曲名字数**分类
(erzigepu=二字... qizigepu=七字), 目录里带曲名。所以按目标曲名的字数挑对应分类, 逐页扫目录,
命中才去下载, 避免把几万张全拖下来。

实测规模(2026-09-22): 四字歌谱 ~1260 页 x 30 条; 分页 URL = /<cat>/<页>.htm (页号越大越新,
基址 /<cat> 即最新一页)。

判据(2026-10-06 复核):
  * **本脚本从来就没有 `[简谱]` 那条过滤**(它是按**分类**扫的 —— 分类本身就等于"是简谱":
    一~九字歌谱/十字及以上/合唱谱/英文歌谱都是简谱, 而 jitapu/gangqinpu/zongpu 这些专用谱类
    根本不在 `CATS` 里)。改版后列表页方括号里装的是**歌手/词曲作者**而不是 `[简谱]`,
    对本脚本**没有影响** —— `norm()` 与 `safe()` 本来就会把方括号连同内容一起砍掉。
  * 但它有一个**同样在悄悄收 0 的判据**: 谱图地址。老页是 `/img/...`, 2025 起的新页改成了
    `/img9/...`, 而这里写死 `^/img/` ⇒ 新页一律报"页面里没匹配到 /img/ 谱图",
    跑完就是"下载 0 个谱页"而退出码还是 0。已改成 `/img\\d*/`(见 `IMG_RE`)。
  * 另修: 一字曲名原来被兜到 `shizijiyishang` 分类(那里一个字的名字一条都没有),
    改成走 `yizigepu`; `hechangpu`(合唱谱)原来整类没被扫, 补进清单 —— 实测该分类 186 页,
    合唱谱只有这里才有。

用法:
  py -3.13 tools/crawl_jianpucn_by_title.py <曲名1,曲名2,...> [每个分类最多扫几页=1400]
"""
import io
import os
import re
import sys
import time
import urllib.request

# `--help` 保护: 本文件是**模块级脚本**, 没有 argparse —— 不拦的话 `--help` 会被当成
# "要爬的曲名", 真的开始扫几万页目录。(同 2026-09-24 给另外三个爬虫加的那道保护。)
# 2026-10-06 修: 这段原来在 `from jp_root import ...` **之后**, 而 `jp_root` 自己也有
# `guard_help(__doc__)` —— 于是 `--help` 打出来的是 jp_root 的文档, 不是本脚本的用法。
# 挪到所有项目内 import 之前, 谁先拦谁说了算。
if any(a in ("-h", "--help") for a in sys.argv[1:]):
    print(__doc__)
    raise SystemExit(0)

# 2026-09-25 修: 这里原来硬编码着作者 Windows 机器的 `os.chdir(r"D:\Documents_D\jianpu2")`,
# 在 Linux 上**直接 FileNotFoundError 崩掉** —— 而这个工具不在 check_tools.sh 的冒烟清单里,
# 所以烂了没人发现。现在按 `__file__` 定位, 与别的工具同一口径。
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # jianpu2/
WS = os.path.dirname(ROOT)                        # 工作区
sys.path.insert(0, HERE)
from jp_root import images_root
from crawl_limits import pages                    # noqa: E402  谱图页数上限: 默认不截断
import tlsfetch                                   # noqa: E402  取页 + 证书过期兜底

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")          # `绿光&nbsp;&nbsp;` -> `绿光`
PAREN = re.compile(r"[（(【\[][^)）】\]]*[)）】\]]|[（(【\[].*$")   # `红茶馆(粤语)` -> `红茶馆`
CATS = ["yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu"]
# 谱图地址(2026-10-06 实测): 老页 `/img/xx/yy/<hash>.jpg|gif`, 2025 起的新页 `/img9/N/xx/<hash>.jpg|png`。
# 旧写法 `^/img/` 匹配不到 `/img9/` —— 60 条样本(六个分类各取新旧两页)旧判据只中 30 条(全是老页),
# 新页 **0 命中**, 于是每首歌都记成"页面里没匹配到 /img/ 谱图", 跑完"下载 0 个谱页"却不报错。
IMG_RE = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)
# 图库统一落工作区 `images-prep/`(JIANPU_IMAGES 可覆盖), 不再写相对路径靠 cwd 对上
IMG_ROOT = images_root()
OUT = os.path.join(IMG_ROOT, "jianpucn-title")
SCANLOG = os.path.join(ROOT, "train-work", "jianpucn_title_scan.tsv")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.dirname(SCANLOG), exist_ok=True)

WANT = [x for x in (sys.argv[1].split(",") if len(sys.argv) > 1 else []) if x]
_args = sys.argv[2:]
# `--from-log`: 不重扫目录, 直接读扫描日志里"已经命中过"的谱页去下载。
# 为什么需要: 扫一遍 6 个分类要 ~40 分钟, 而"扫描"和"下载"是两件事 ——
# 2026-09-25 实测下载静默失败(报"下载 0 个谱页", 退出码还是 0), 想重试就得再等 40 分钟重扫。
FROM_LOG = "--from-log" in _args
MAXP = int([a for a in _args if a.isdigit()][0]) if [a for a in _args if a.isdigit()] else 1400


def norm(s):
    s = ENT.sub("", s)
    s = re.sub(r"\[[^\]]*\]", "", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[0-9０-９]+$", "", s)
    return DROP.sub("", s.translate(ZW)).casefold()


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    为什么必须按语料判: 这个工具是"逐页扫目录"的, 扫一遍 6 个分类要 ~40 分钟; 而目标曲名里
    很多语料里早就有(实测 1764 条转写队列几乎全是重复), 光靠"图目录在不在"判会白扫一场。
    导入失败也照常抓(宁可多下, 不要因为索引坏了整轮空转)。
    """
    try:
        if HERE not in sys.path:
            sys.path.insert(0, HERE)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None


WANTN = {w: norm(w) for w in WANT}
if not WANT:
    sys.exit(__doc__)

# **先按语料剪目标**: 曲名已经在语料里的, 连目录都不用扫。
_ci = _corpus_index()
SKIP = [w for w in WANT if _ci.title_in_corpus(w)] if _ci is not None else []
if SKIP:
    print("语料里已有 %d 首, 不再扫目录/下载: %s%s"
          % (len(SKIP), "、".join(SKIP[:8]), " ..." if len(SKIP) > 8 else ""), flush=True)
WANT = [w for w in WANT if w not in set(SKIP)]
WANTN = {w: norm(w) for w in WANT}
if not WANT:
    print("\n%d 首目标全在语料里, 无事可做(跳过 %d 条)" % (len(SKIP), len(SKIP)))
    sys.exit(0)


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "http://www.jianpu.cn/"})
    with tlsfetch.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", "replace")


def safe(s):
    # 2026-09-25: 站点标题里的 `&nbsp;&nbsp;` 会原样进目录名 -> 再一路漏进转写队列的"曲名"列 ->
    # 转写完就成了 `title=阿姐鼓&nbsp;&nbsp;`。这里先去实体。
    s = ENT.sub("", s)
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", re.sub(r"\[[^\]]*\]", "", s)).strip()[:60] or "untitled"


def ext_of(data):
    """按**魔数**定扩展名 —— 站点上的谱图既有 .jpg 也有 .gif/.png, 不能一律存成 .jpg。"""
    if data[:4] == b"\x89PNG":
        return ".png"
    if data[:3] == b"GIF":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


def matched(title_norm, want_norm):
    """短标题(<=3 字)必须精确相等 —— 否则《红豆》会命中《红豆杉》《红豆情》这类无关谱。"""
    if want_norm == title_norm:
        return True
    if len(want_norm) <= 3:
        return False
    return want_norm in title_norm


# 只扫需要的分类(按目标曲名字数)
# 2026-10-06 修两处: ① 一字曲名原来落进 `shizijiyishang`(那里的曲名都是十字以上, 一条都命不中),
# 改成 `yizigepu`; ② `hechangpu`(合唱谱)整类没被扫过 —— 合唱谱只有这个分类里才有, 补进来。
need_cat = set()
for w in WANT:
    ln = len(re.findall(r"[\u4e00-\u9fff]", w))
    need_cat.add({1: "yizigepu", 2: "erzigepu", 3: "sanzigepu", 4: "sizigepu", 5: "wuzigepu",
                  6: "liuzigepu", 7: "qizigepu", 8: "bazigepu", 9: "jiuzigepu",
                  10: "shizijiyishang"}.get(min(ln, 10), "shizijiyishang"))
need_cat.add("hechangpu")
print(f"目标 {len(WANT)} 首 -> 需扫分类 {sorted(need_cat)}\n", flush=True)

found = {}          # 曲名 -> [(url, title)]
if FROM_LOG:
    # 日志里每行: 曲名 \t 页面标题 \t /pu/NN/NNNNNN.htm \t 分类 \t p页号
    seen = set()
    for ln in io.open(SCANLOG, encoding="utf-8"):
        c = ln.rstrip("\n").split("\t")
        if len(c) < 3 or c[0] not in WANTN:
            continue
        key = (c[0], c[2])
        if key in seen:
            continue
        seen.add(key)
        found.setdefault(c[0], []).append((c[2], c[1]))
    print(f"--from-log: 从 {SCANLOG} 读到 {sum(len(v) for v in found.values())} 个谱页, 跳过目录扫描\n",
          flush=True)
else:
    log = io.open(SCANLOG, "a", encoding="utf-8")
    for cat in CATS:
        if cat not in need_cat:
            continue
        t0 = time.time()
        for p in range(1, MAXP + 1):
            u = f"http://www.jianpu.cn/{cat}" + ("" if p == 1 else f"/{p}.htm")
            try:
                h = get(u)
            except Exception:
                break
            items = re.findall(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{1,70})<", h)
            if not items:
                break
            for path, title in items:
                tn = norm(title)
                for w, wn in WANTN.items():
                    if wn and matched(tn, wn) and path not in {x[0] for x in found.get(w, [])}:
                        found.setdefault(w, []).append((path, title.strip()))
                        print(f"   命中 {w} <- {title.strip()[:44]}  {path}", flush=True)
                        log.write(f"{w}\t{title.strip()}\t{path}\t{cat}\tp{p}\n")
                        log.flush()
            if p % 100 == 0:
                print(f"  [{cat}] 第 {p} 页 ({time.time()-t0:.0f}s) 累计命中 "
                      f"{sum(len(v) for v in found.values())}", flush=True)
            time.sleep(0.15)
        print(f"  [{cat}] 扫完 {p} 页, 用时 {time.time()-t0:.0f}s", flush=True)
    log.close()

print(f"\n命中 {sum(len(v) for v in found.values())} 个谱页, 开始下载")
ok = 0
skipped = _ci.SkipCounter() if _ci is not None else None
fails = {}          # 失败原因 -> 次数 (别再静默吞异常了)
for w, lst in found.items():
    for path, title in lst:
        sid = re.search(r"/(\d+)\.htm", path).group(1)
        # 语料里已有 -> 跳过(站内 id 或曲名)。放在**下载前**, 免得白下几百张图再被判重。
        if _ci is not None:
            r = _ci.skip_reason("jianpucn", sid, title)
            if r:
                skipped.count(r)
                if r == "title":
                    skipped.note_title_skip("%s (%s)" % (title[:40], w))
                continue
        d = os.path.join(OUT, f"{safe(title)}__jianpucn-{sid}")
        # 判"已在"要**忽略 `.part`**: 原子落盘(见下面的图片写入)被杀进程时只留 `00N.jpg.part`,
        # 那不是成品图。不排除的话这种目录会被当成"下过了", 那一页就**永远补不回来**。
        if os.path.isdir(d) and [x for x in os.listdir(d) if not x.endswith(".part")]:
            ok += 1
            continue
        try:
            ph = get("http://www.jianpu.cn" + path)
        except Exception as e:
            fails["页面取不到: " + type(e).__name__] = fails.get("页面取不到: " + type(e).__name__, 0) + 1
            continue
        imgs = [x for x in IMG_RE.findall(ph) if "logo" not in x.lower()]
        if not imgs:
            fails["页面里没匹配到谱图(/img\\d*/)"] = fails.get("页面里没匹配到谱图(/img\\d*/)", 0) + 1
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        # 2026-10-06 修: 原来写死 `imgs[:3]` —— 实测详情页最多有 6 张(《93海阔天空》), 只存 3 张
        # 会让后面几页**永远下不到**。默认全部(可用 `JIANPU_MAX_PAGES` 给上限)。
        for iu in pages(imgs):
            try:
                req = urllib.request.Request("http://www.jianpu.cn" + iu,
                                             headers={"User-Agent": UA})
                with tlsfetch.urlopen(req, timeout=25) as r:
                    data = r.read()
                # 扩展名按**魔数**定: 站点上不少谱图是 .gif/.png, 老写法一律存成 .jpg(假后缀)
                # 原子落盘(.part -> os.replace): 硬止损杀进程时只留 .part, 不留截断图(口径同 crawl_jianpucn.py)
                fn = os.path.join(d, f"00{n+1}{ext_of(data)}")
                part = fn + ".part"
                with open(part, "wb") as g:
                    g.write(data)
                os.replace(part, fn)
                n += 1
            except Exception as e:
                fails["图片下载失败: " + type(e).__name__] = fails.get("图片下载失败: " + type(e).__name__, 0) + 1
            time.sleep(0.15)
        if n:
            ok += 1
            print(f"   + {w} <- {title[:44]} ({n} 张)", flush=True)
        time.sleep(0.2)

print(f"\n完成: 下载 {ok} 个谱页 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
if fails:
    print("失败原因统计(以前这里是静默 `except: continue`, 所以只会看到\"下载 0\"):")
    for k, v in sorted(fails.items(), key=lambda kv: -kv[1]):
        print("   %-34s %d" % (k, v))
for w in WANT:
    print(f"   {w:<16} {'命中 ' + str(len(found.get(w, []))) + ' 个谱页' if w in found else '未命中'}")
