# -*- coding: utf-8 -*-
"""qupu123「通俗唱法」整片扫描入库 —— 断点续爬, 每次推进一段。

为什么: 用户指出"我揪出一首歌, 你要补的是一片, 不是补那一张"。
实测 qupu123 的 /tongsu/ = **17819 条 / 713 页, 全是简谱**(全库目前总共才 7296 份) —— 这是
单站单分类就有的 2.4 倍扩库空间。所以做法不是逐个歌名打补丁, 而是**顺序把这一整片扫进来**:
每跑一次推进 SWEEP_MAX 张, 把"下一页从哪儿开始"写进状态文件, 下次接着来(可反复调度)。

抗限流: qupu123 约在每类第 80-190 页开始限流, 所以失败要退避重试, 连续 6 页失败才收工。

用法: py -3.13 tools/crawl_qupu123_sweep.py [本次最多几张=400] [起始页=自动]
"""
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
BASE = "https://www.qupu123.com"
OUT = "images-prep/qupu123-sweep"
STATE = "train-work/qupu123_sweep_state.tsv"
os.makedirs(OUT, exist_ok=True)

CAP = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
START = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else None
if START is None:
    START = 1
    if os.path.exists(STATE):
        try:
            START = int(io.open(STATE, encoding="utf-8").read().split("\t")[0]) + 1
        except Exception:
            START = 1


def get(u, binary=False):
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=35) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


print(f"整片扫描 /tongsu/  本次上限 {CAP} 张, 从第 {START} 页起", flush=True)
got = seen_state = 0
fail_streak = 0
page = START
while got < CAP and fail_streak < 6:
    u = f"{BASE}/tongsu/" + ("" if page == 1 else f"{page}.html")
    h = None
    for t in range(4):
        try:
            h = get(u)
            break
        except Exception:
            time.sleep(2.0 * (t + 1))
    if h is None:
        fail_streak += 1
        print(f"   第 {page} 页失败(第 {fail_streak} 次连续)", flush=True)
        page += 1
        continue
    fail_streak = 0
    items = re.findall(r'href="(/tongsu/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html)"[^>]*>([^<]{2,90})<', h)
    if not items:
        print(f"   第 {page} 页无条目, 收工", flush=True)
        break
    for path, title in items:
        if got >= CAP:
            break
        sid = re.search(r"/p(\d+)\.html$", path)
        sid = sid.group(1) if sid else os.path.basename(path)[:-5]
        d = os.path.join(OUT, f"{safe(title)}__qupu123-{sid}")
        if os.path.isdir(d) and os.listdir(d):
            seen_state += 1
            continue
        try:
            ph = get(BASE + path)
        except Exception:
            continue
        imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
        imgs = [urllib.parse.urljoin(BASE + "/", x) for x in dict.fromkeys(imgs)]
        imgs = [x for x in imgs if "/Public/Uploads/" in x or "/data2/uploads/" in x]
        if not imgs:
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        for iu in imgs[:6]:
            try:
                data = get(iu, binary=True)
            except Exception:
                continue
            if len(data) < 8000:
                continue
            try:
                from PIL import Image as _I
                import io as _io
                if min(_I.open(_io.BytesIO(data)).size) < 400:
                    continue
            except Exception:
                pass
            ext = ".png" if data[:4] == b"\x89PNG" else ".jpg"
            with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
                g.write(data)
            n += 1
            time.sleep(0.1)
        if n:
            got += 1
            if got % 25 == 0:
                print(f"   [{got}/{CAP}] 第{page}页 {title[:40]}", flush=True)
        time.sleep(0.18)
    io.open(STATE, "w", encoding="utf-8").write(f"{page}\t{got}\n")
    page += 1
    time.sleep(0.3)

print(f"\n本次新增 {got} 张 (跳过已存在 {seen_state}), 已到第 {page-1} 页 -> {OUT}")
print(f"下次从第 {page} 页继续(状态写在 {STATE})")
