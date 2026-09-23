# -*- coding: utf-8 -*-
"""诊断时值线判定: 打印某几个 crop 的逐行跨度, 看是几条下划线、被算成几级。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from geo_detect import geo_detect

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

# 第1行: 5 | 1 1 1 3 | 5 5 5 5 5 | 3 3 | 2 2 3 2 1
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    if frac < 0.85:
        continue
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    regs = T.crop_note_regions(sub)
    print(f"行带 y[{s},{e}]  bar_extent={be}  块数={len(regs)}\n")
    for k, (nx0, nx1, ny0, ny1) in enumerate(regs):
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        gd = geo_detect(crop)
        m = crop < 170
        spans = []
        for y in range(crop.shape[0]):
            xr = np.where(m[y])[0]
            spans.append(int(xr.max() - xr.min() + 1) if len(xr) else 0)
        print(f"[{k:2d}] x[{nx0:3d},{nx1:3d}] crop={crop.shape}  {gd}")
        print(f"     逐行跨度: {spans}")
        if k >= 7:
            break
    break
