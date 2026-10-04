# -*- coding: utf-8 -*-
"""爬 jianpujia(简谱之家) 的曲谱。

为什么选它: 它的简谱是**排版渲染图**(不是扫描件), 笔画锐利、无水印, 虽只有 664-1125px
但 OCR 效果远好于 jianpucn 的同分辨率扫描图。实测对比见 train-work/jianpujia简谱样本.jpg。

站内结构:
  分类页  http://www.jianpujia.com/list/<cat>-<page>.html   例: 583 = 周杰伦
  曲谱页  http://www.jianpujia.com/jianpu/<id>.html          (吉他谱是 /jitapu/)
  图片    https://image.jianpujia.com/...                    (无扩展名, 需嗅探)

用法:
  py tools/crawl_jianpujia.py 583 周杰伦 200
  py tools/crawl_jianpujia.py 1252 邓丽君 200
"""
import os
import re
import sys
import time
import urllib.request

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# --help 保护: 这三个爬虫没有 argparse, 万一被当冒烟测试跑起来会**真的开始下载** —— 直接打文档退出。
if any(a in ("-h", "--help") for a in sys.argv[1:]):
    print(__doc__)
    raise SystemExit(0)


UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CAT = sys.argv[1] if len(sys.argv) > 1 else "583"
NAME = sys.argv[2] if len(sys.argv) > 2 else "周杰伦"
TARGET = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 150
# 图库落在**工作区**的 `images-prep/`(旧的 8.9GB 图库就在那儿, 单一存储);
# 用 JIANPU_IMAGES 可以指到别处。以前是相对 cwd 的 "images-prep" —— 而本脚本会 chdir 到 jianpu2/,
# 于是新爬的图跑进 jianpu2/images-prep/, 跟工作区那份**劈成了两个库**(2026-09-25 发现并修)。
_WS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # 工作区(三个 dirname: tools/x.py -> tools -> jianpu2 -> 工作区)
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or os.path.join(_WS, "images-prep")
OUT = os.path.join(IMG_ROOT, f"jianpujia-{CAT}")
os.makedirs(OUT, exist_ok=True)


def fetch(url, binary=False, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "http://www.jianpujia.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


# 本文件所在目录(tools/) —— 取共用模块 `corpus_index` 用; 别的爬虫里 `sys.path.insert(0, "tools")`
# 是靠"先 chdir 到仓库根"才对上的, 这里不依赖 cwd。
_TOOLS = os.path.dirname(os.path.abspath(__file__))


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


# 1) 翻分类页, 收集 /jianpu/ 详情页(跳过 /jitapu/ 吉他谱)
items = []
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

ok = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
for i, (path, title) in enumerate(items, 1):
    sid = re.search(r"/(\d+)\.html", path).group(1)
    # 语料里已有 -> 跳过(站内 id 或曲名), 连详情页都不请求
    if _ci is not None:
        r = _ci.skip_reason("jianpujia", sid, title)
        if r:
            skipped.count(r)
            if r == "title":
                skipped.note_title_skip(title[:44])
            continue
    d = os.path.join(OUT, f"{safe(title)}__jianpujia-{sid}")
    if os.path.isdir(d) and os.listdir(d):
        ok += 1
        continue
    try:
        ph = fetch("http://www.jianpujia.com" + path)
    except Exception:
        continue
    imgs = re.findall(r'<img[^>]+src="((?:https?:)?//image\.jianpujia\.com/[^"]+)"', ph, re.I)
    if not imgs:
        continue
    os.makedirs(d, exist_ok=True)
    n = 0
    for k, iu in enumerate(dict.fromkeys(imgs)):
        full = iu if iu.startswith("http") else "http:" + iu
        try:
            data = fetch(full, binary=True, timeout=30)
        except Exception:
            continue
        if len(data) < 3000:      # 太小的多半是图标
            continue
        # 嗅探格式
        ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
        with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
            g.write(data)
        n += 1
        time.sleep(0.15)
    if n:
        ok += 1
        if ok % 20 == 0:
            print(f"  [{ok}/{len(items)}] {title[:40]}", flush=True)
    time.sleep(0.25)

print(f"\n完成: {ok} 首 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
