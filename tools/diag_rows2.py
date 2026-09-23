# -*- coding: utf-8 -*-
"""诊断: fine_rows / split_row_inner 对某张谱给出的行带是否正确。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

targets = [("将进酒", "images-prep/qupu123-crawl/将进酒__qupu123-382162")]
for d in glob.glob("images-prep/*/*春天在哪里*"):
    targets.append(("spring", d))

for label, d in targets:
    fs = sorted(glob.glob(os.path.join(d, "*.jpg")), key=os.path.getsize)
    if not fs:
        print(f"{label}: 无图")
        continue
    src = fs[-1]
    arr = np.asarray(Image.open(src).convert("L"))
    content = arr < T.TOL
    print(f"\n=== {label} ===  图 {arr.shape[1]}x{arr.shape[0]}  ROW_GAP={T.ROW_GAP}  BAR_THR={T.BAR_THR}")
    raw = T.fine_rows(content, T.ROW_GAP)
    print(f"fine_rows 原始行带: {len(raw)} 个")
    for s, e in raw[:14]:
        nbar = T.count_bars(content[s:e + 1], e - s + 1)
        flag = "<-- 通过" if nbar >= T.BAR_THR else "(拒)"
        print(f"   y[{s:4d},{e:4d}]  h={e-s+1:4d}  小节线={nbar}  {flag}")
    if len(raw) > 14:
        print(f"   ... 共 {len(raw)} 个")
    bands = []
    for s0, e0 in raw:
        bands += T.split_row_inner(content, s0, e0)
    print(f"split_row_inner 后: {len(bands)} 个")
