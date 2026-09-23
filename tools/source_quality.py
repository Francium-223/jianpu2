# -*- coding: utf-8 -*-
"""量各源的图片清晰度: 按目录名的 __<源>-<id> 后缀分组, 统计每首谱的主图宽高。
用来判断哪个站值得爬(分辨率高 = 更适合 OCR)。
"""
import glob, os, re, statistics, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
from PIL import Image

groups = {}
for d in glob.glob("images-prep/*/*"):
    if not os.path.isdir(d):
        continue
    m = re.search(r"__([a-z0-9.]+)-(\d+)$", os.path.basename(d))
    if not m:
        continue
    src = m.group(1)
    # 取该目录下最大的一张图(主谱页)
    best = None
    for f in glob.glob(d + "/*"):
        if os.path.splitext(f)[1].lower() not in (".jpg", ".jpeg", ".png", ".gif"):
            continue
        try:
            im = Image.open(f)
            a = im.width * im.height
            if best is None or a > best[0]:
                best = (a, im.width, im.height)
        except Exception:
            pass
    if best:
        groups.setdefault(src, []).append((best[1], best[2]))

print(f"{'源':<14}{'谱数':>6}{'中位宽':>8}{'中位高':>8}{'中位像素':>10}{'>=1500宽占比':>12}")
print("-" * 62)
rows = []
for src, v in groups.items():
    ws = [x[0] for x in v]
    hs = [x[1] for x in v]
    px = [x[0] * x[1] for x in v]
    big = sum(1 for w in ws if w >= 1500) / len(ws)
    rows.append((statistics.median(ws), src, len(v), statistics.median(hs),
                 statistics.median(px), big))
for mw, src, n, mh, mp, big in sorted(rows, reverse=True):
    print(f"{src:<14}{n:>6}{mw:>8.0f}{mh:>8.0f}{mp:>10.0f}{100*big:>11.0f}%")
