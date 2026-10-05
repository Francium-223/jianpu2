# -*- coding: utf-8 -*-
"""爬 jianpujia(简谱之家) 的曲谱。

为什么选它: 它的简谱是**排版渲染图**(不是扫描件), 笔画锐利、无水印, 虽只有 664-1125px
但 OCR 效果远好于 jianpucn 的同分辨率扫描图。实测对比见 train-work/jianpujia简谱样本.jpg。

站内结构:
  分类页  http://www.jianpujia.com/list/<cat>-<page>.html   例: 583 = 周杰伦
  曲谱页  http://www.jianpujia.com/jianpu/<id>.html          (吉他谱是 /jitapu/)
  图片    https://image.jianpujia.com/...                    (见下面 `IMG_RE` 的注释)

用法:
  py tools/crawl_jianpujia.py 583 周杰伦 200                        # 按分类翻页抓
  py tools/crawl_jianpujia.py --seeds 157673                        # 按站内 id 直接抓(曲名从详情页取)
  py tools/crawl_jianpujia.py --seeds 157673 160000 --out images-prep

2026-10-06 修(这是"收 0 首"的根因): 曲谱页把谱图写成**没有引号的** src 属性 ——
    <p style="text-align: center;"><img alt="…" width="760" border=0
        src=https://image.jianpujia.com/jianpudq/jianpu30/<hash>.png></p>
而老判据要求 `src="…"`(带引号且值是 `//image.jianpujia.com/…`), 对这种页 **0 命中** ⇒ 每首歌
都静默 `continue`, 跑完"完成: 0 首"而退出码还是 0(与 jianpucn 那一族"判据过期"同一类毛病)。
实测 `/jianpu/157673.html`: 老判据 0 条 / 新判据 1 条。断言已加进
`tools/check_jianpucn_filter.py`(那一族自检现在把 jianpujia 也纳进来了)。
"""
import os
import re
import sys
import time
import urllib.request

_TOOLS = os.path.dirname(os.path.abspath(__file__))
if _TOOLS not in sys.path:
    sys.path.insert(0, _TOOLS)
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# --help 保护: 这三个爬虫没有 argparse, 万一被当冒烟测试跑起来会**真的开始下载** —— 直接打文档退出。
if any(a in ("-h", "--help") for a in sys.argv[1:]):
    print(__doc__)
    raise SystemExit(0)


UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
# 图库口径: **必须**走 `jp_root.images_root()`(全仓库唯一口径, 与 `crawl_jianpujia_search.py` /
# `crawl_jianpucn.py` 同一口径; `JIANPU_IMAGES` 可覆盖, jp_root 自己也认这个变量)。
# 原来这里自己算 `_WS` = 三个 dirname = `D:\Documents_D`, 再拼 `images-prep` —— 于是图落进
# **D:\Documents_D\images-prep** 这个"另一个库"(实测 2026-10-06: 那个目录里只有爬虫下的图,
# 规范库 jianpu2\images-prep 里没有), 正是 2026-09-25 那条注释说要修掉的"劈成两个库"的毛病 ——
# 只是当时层级算错了一级(dirname 数多了), 注释写着修好了、实际还是在劈。
from jp_root import images_root     # noqa: E402
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or images_root()

# 谱图地址判据 —— **属性值可能没有引号**(实测 2026-10-06, 见模块 docstring): 三种引号形态都要认,
# 双引号 / 单引号 / 完全没引号。句尾再按图床域名 `image.jianpujia.com` 过滤(站标 logo 在
# `www.jianpujia.com/skin/...` 上, 不是这个域名, 天然被挡掉)。
IMG_RE = re.compile(r"""<img[^>]+\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))""", re.I)
# 曲名判据(实测): `<h1>大东北我的家乡简谱_何玉演唱歌曲_小叶子159曲谱-简谱</h1>`
# = `<曲名>简谱_<歌手>演唱歌曲_<上传者>曲谱-简谱` ⇒ 取第一个 `简谱` 之前那段。
H1_RE = re.compile(r"<h1[^>]*>(.*?)</h1>", re.S | re.I)
TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S | re.I)


def fetch(url, binary=False, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "http://www.jianpujia.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


def img_of(html):
    """谱图 URL 列表(去重保序) —— 三种引号形态 + 按图床域名认定, 不要求扩展名。

    实测那条 `src=` 没引号, 所以判据不能只认引号; 而 `image.jianpujia.com` 这个域名只出谱图
    (站标/二维码都在别的域名或别的站点上), 所以域名判据够准。
    """
    out = []
    for m in IMG_RE.finditer(html):
        u = m.group(1) or m.group(2) or m.group(3) or ""
        if "image.jianpujia.com" not in u.lower():
            continue
        if u not in out:
            out.append(u)
    return out


def song_title(html, sid):
    """曲名 —— 只认 `<h1>`(实测 `大东北我的家乡简谱_何玉演唱歌曲_小叶子159曲谱-简谱`),
    取第一个 `简谱` 之前那段; 没有 h1 就退到 `<title>`(同一形态), 再不行带上 id 兜底。"""
    m = H1_RE.search(html) or TITLE_RE.search(html)
    raw = re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""
    raw = re.split(r"简谱", raw)[0].strip()
    t = safe(raw)
    return t if t else "untitled-%s" % sid


# 本文件所在目录(tools/) 见文件顶部的 `_TOOLS`(取共用模块 `corpus_index` 用, 不依赖 cwd)。


def has_images(d):
    """目录里有没有**成品图**(忽略原子写的 `.part` 半成品)。

    续爬判据原来是"目录非空就算已抓"(`os.listdir(d)`), 而 `.part` 本身也是一个文件 —— 于是一次
    硬止损(直接杀进程)留下的半成品会让这首**永远不再抓**, 比截断图还隐蔽。判据收窄到真图片后缀。
    """
    if not os.path.isdir(d):
        return False
    return any(f.lower().endswith((".jpg", ".jpeg", ".png", ".gif", ".webp")) for f in os.listdir(d))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本爬虫原来只按"图目录在不在"判已抓过(`os.path.isdir(d) and os.listdir(d)`), 而图目录与语料
    是两套账: 同一首歌从别的源抓过、或者转过写之后目录被挪过的, 都会再抓一遍(2026-10-04 实测
    那一轮 1764 条转写队列几乎全是重复, 净增 1 首)。曲名/站内 id 命中语料就整条跳过。
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


def split_flags(argv):
    """把 `--seeds a b` / `--out DIR` 摘出来, 剩下的还是位置参数(`分类 歌手 目标数`)。

    为什么不用 argparse: 本脚本原来的跑法就是位置参数, 换 argparse 会把已有用法和文档全打乱;
    这里只"摘开关", 两种跑法并存。
    """
    opts = {"--seeds": [], "--out": ""}
    rest, i = [], 0
    while i < len(argv):
        a = argv[i]
        if a == "--seeds":
            i += 1
            while i < len(argv) and argv[i].isdigit():
                opts["--seeds"].append(argv[i])
                i += 1
            continue
        if a == "--out":
            if i + 1 < len(argv):
                opts["--out"] = argv[i + 1]
            i += 2
            continue
        rest.append(a)
        i += 1
    return opts, rest


OPTS, POS = split_flags(sys.argv[1:])
SEEDS = OPTS["--seeds"]
CAT = POS[0] if len(POS) > 0 else "583"
NAME = POS[1] if len(POS) > 1 else "周杰伦"
TARGET = int(POS[2]) if len(POS) > 2 and POS[2].isdigit() else 150

# 1) 收集 /jianpu/ 详情页 —— 种子模式直接用 id, 分类模式翻分类页(跳过 /jitapu/ 吉他谱)
items = []                                  # [(页址, 列表页标题; 种子模式为空串)]
if SEEDS:
    items = [("/jianpu/%s.html" % s, "") for s in SEEDS]
    OUT = OPTS["--out"] or IMG_ROOT          # 种子模式直接落 images-prep/<曲名>__jianpujia-<id>
    print("种子模式: %d 个曲谱 id -> %s" % (len(items), OUT))
else:
    OUT = OPTS["--out"] or os.path.join(IMG_ROOT, f"jianpujia-{CAT}")
    for page in range(0, 40):
        url = f"http://www.jianpujia.com/list/{CAT}-{page}.html"
        try:
            h = fetch(url)
        except Exception:
            break
        found = re.findall(r'href="(/jianpu/(\d+)\.html)"[^>]*>([^<]{2,90})', h)
        if not found:
            break
        new = [(i, t) for i, _id, t in found if i not in {x[0] for x in items}]
        if not new:
            break
        items.extend(new)
        print(f"  分类第 {page} 页: +{len(new)} (累计 {len(items)})", flush=True)
        if len(items) >= TARGET:
            break
        time.sleep(0.3)
    items = items[:TARGET]
    print(f"\n{NAME}: 收集到 {len(items)} 个简谱页, 开始下载")

os.makedirs(OUT, exist_ok=True)

ok = n_imgs = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
fails = {}                                  # 失败/空手的原因 -> 次数(别再"悄悄收 0 张图"还退出 0)
for i, (path, title) in enumerate(items, 1):
    sid = re.search(r"/(\d+)\.html", path).group(1)
    ph = None
    if not title:                           # 种子模式: 曲名只能从详情页取, 先取页
        try:
            ph = fetch("http://www.jianpujia.com" + path)
        except Exception as e:
            fails["曲谱页取不到: " + type(e).__name__] = fails.get("曲谱页取不到: " + type(e).__name__, 0) + 1
            continue
        title = song_title(ph, sid)
    # 语料里已有 -> 跳过(站内 id 或曲名), 连详情页都不请求(种子模式已经取过页了)
    if _ci is not None:
        r = _ci.skip_reason("jianpujia", sid, title)
        if r:
            skipped.count(r)
            if r == "title":
                skipped.note_title_skip(title[:44])
            continue
    d = os.path.join(OUT, f"{safe(title)}__jianpujia-{sid}")
    if has_images(d):
        ok += 1
        continue
    if ph is None:
        try:
            ph = fetch("http://www.jianpujia.com" + path)
        except Exception as e:
            fails["曲谱页取不到: " + type(e).__name__] = fails.get("曲谱页取不到: " + type(e).__name__, 0) + 1
            continue
    imgs = img_of(ph)
    if not imgs:
        fails["页面里没匹配到谱图(image.jianpujia.com)"] = \
            fails.get("页面里没匹配到谱图(image.jianpujia.com)", 0) + 1
        continue
    os.makedirs(d, exist_ok=True)
    n = 0
    for k, iu in enumerate(dict.fromkeys(imgs)):
        full = iu if iu.startswith("http") else "http:" + iu
        try:
            data = fetch(full, binary=True, timeout=30)
        except Exception as e:
            fails["图片下载失败: " + type(e).__name__] = fails.get("图片下载失败: " + type(e).__name__, 0) + 1
            continue
        if len(data) < 3000:      # 太小的多半是图标
            fails["图太小(<3KB), 当图标丢掉"] = fails.get("图太小(<3KB), 当图标丢掉", 0) + 1
            continue
        # 嗅探格式
        ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
        # **原子落盘**(.part -> os.replace): 抓取随时可能被磁盘硬止损**直接杀进程**, 直接写目标名会在
        # 图目录里留一张截断图 —— 而续爬只看文件名在不在, 会把半张图当成品永久收下。先写 `.part`
        # (不在上面的图片后缀白名单里, `has_images` 不认), 写完再 rename; 被杀时最多留一个 .part,
        # 下次照常重抓。口径与 `crawl_fysongs.py` / `crawl_jianpucn.py` 一致。
        gp = os.path.join(d, f"00{n+1}{ext}")
        part = gp + ".part"
        with open(part, "wb") as g:
            g.write(data)
        os.replace(part, gp)
        n += 1
        time.sleep(0.15)
    if n:
        ok += 1
        n_imgs += n
        print(f"  + {title[:40]} <- {path} ({n} 张) -> {os.path.basename(d)}", flush=True)
    time.sleep(0.25)

print(f"\n完成: {ok} 首 / 谱图 {n_imgs} 张 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
if fails:
    print("空手/失败统计(以前这些是静默 `continue`, 所以只会看到\"完成: 0 首\"):")
    for k, v in sorted(fails.items(), key=lambda kv: -kv[1]):
        print("   %-40s %d" % (k, v))
