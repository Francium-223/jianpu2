# -*- coding: utf-8 -*-
"""补两个数: ①硬截断到底丢了多页 ②qupu123 单图字节(按爬虫自己的过滤口径)。

① 为什么这样测: 直接对随机详情页抽样**低估**多图曲(多图的大多是老热门曲, 在随机样本里占比低)。
   最准的办法是反着来 —— 专挑**已经被截断过的**目录(恰好剩 2 张 / 恰好剩 3 张), 重新请求详情页,
   数真实图数, 差额就是这次修复能捞回来的页数。
② 单图字节: 用爬虫同款过滤(>=8KB 且 PIL 短边 >=400)再量, 否则会把页面上 750x55 的横幅算进去。

只读(不动图库、不删目录), >=1 秒/请求。
"""
import glob
import os
import random
import re
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402
from crawl_limits import throttle  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
Q = "https://www.qupu123.com"
J = "http://www.jianpu.cn"
IMG = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)
DIRSID = re.compile(r"__(?P<site>[a-z0-9]+)-(?P<sid>[0-9a-z_]+)$")
JIMG = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)


def jget(u, binary=False):
    throttle()
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": J + "/"})
    with urllib.request.urlopen(req, timeout=35) as r:
        raw = r.read()
    return raw if binary else raw.decode("gbk", errors="replace")


def qget(u, binary=False):
    throttle()
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": Q + "/"})
    with tlsfetch.urlopen(req, timeout=45) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


# ---------- ① 截断损失: 挑"恰好 N 张"的 jianpucn 目录, 重测真实图数 ----------
print("############ ① jianpucn 截断损失(专挑恰好 2/3 张的目录) ############", flush=True)
roots = [d for d in glob.glob(os.path.join("images-prep", "jianpucn*")) if os.path.isdir(d)]
by_n = {2: [], 3: []}
for root in roots:
    for dirpath, dirnames, _f in os.walk(root):
        for d in dirnames:
            m = DIRSID.search(d)
            if not m or m.group("site") != "jianpucn":
                continue
            try:
                n = len([f for f in os.listdir(os.path.join(dirpath, d)) if IMG.search(f)])
            except OSError:
                continue
            if n in by_n:
                by_n[n].append((d, m.group("sid")))
print("  恰好 2 张的目录 %d 个 · 恰好 3 张的 %d 个" % (len(by_n[2]), len(by_n[3])), flush=True)
random.seed(7)
for n in (2, 3):
    random.shuffle(by_n[n])
    lost_dirs = 0
    extra = 0
    tested = 0
    hist = {}
    for d, sid in by_n[n][:25]:
        u = "%s/pu/%s/%s.htm" % (J, sid[:2], sid)
        try:
            h = jget(u)
        except Exception:
            continue
        true_n = len([z for z in dict.fromkeys(JIMG.findall(h)) if "logo" not in z.lower()])
        hist[true_n] = hist.get(true_n, 0) + 1
        tested += 1
        if true_n > n:
            lost_dirs += 1
            extra += true_n - n
    if tested:
        print("  恰好 %d 张: 实测 %d 个目录 · 真实图数分布 %s" % (n, tested, dict(sorted(hist.items()))), flush=True)
        print("     -> 其中 %d/%d 个被截断过(%.1f%%), 共少下 %d 页, 平均每个目录少 %.2f 页"
              % (lost_dirs, tested, 100.0 * lost_dirs / tested, extra, extra / tested), flush=True)

# ---------- ② qupu123 单图字节(爬虫同款过滤) ----------
print("\n############ ② qupu123 单图字节(按爬虫过滤口径) ############", flush=True)
qs = []
for p in (1, 60, 200, 500):
    u = "%s/tongsu/" % Q if p == 1 else "%s/tongsu/%d.html" % (Q, p)
    try:
        h = qget(u)
    except Exception:
        continue
    qs += re.findall(r'href="(/tongsu/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html)"', h)[:6]
qs = list(dict.fromkeys(qs))
print("  取样 %d 个详情页" % len(qs), flush=True)
sizes = []
kept_per_song = []
for path in qs[:12]:
    try:
        h = qget(Q + path)
    except Exception:
        continue
    imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', h, re.I)
    imgs = [urllib.parse.urljoin(Q + "/", x) for x in dict.fromkeys(imgs)]
    imgs = [x for x in imgs if "/Public/Uploads/" in x or "/data2/uploads/" in x]
    kept = 0
    for iu in imgs:
        try:
            data = qget(iu, binary=True)
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
        sizes.append(len(data))
        kept += 1
    kept_per_song.append((len(imgs), kept))
    print("    %-38s 页面图 %d · 过滤后 %d" % (path, len(imgs), kept), flush=True)
if sizes:
    ss = sorted(sizes)
    print("  qupu123 单图字节(过滤后, %d 张): 均值 %.0f KB · 中位 %.0f KB · p90 %.0f KB"
          % (len(ss), sum(ss) / len(ss) / 1024, ss[len(ss) // 2] / 1024, ss[int(len(ss) * .9)] / 1024), flush=True)
if kept_per_song:
    print("  每首保留图数: %s" % kept_per_song, flush=True)
print("\nDONE", flush=True)
