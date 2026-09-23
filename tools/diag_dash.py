# -*- coding: utf-8 -*-
"""量真实延音杠('-')的尺寸: 找 兄弟抱一下 行内"不与数字x重叠"的横线, 打印 w/h。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T, transcribe_qwen as Q

for IMG in ["train-work/gt/兄弟抱一下.jpg", "train-work/gt/时间都去哪了.jpg"]:
    arr = np.asarray(Image.open(IMG).convert("L")); content = arr < T.TOL
    rows = [(s, e) for s, e in T.fine_rows(content, T.ROW_GAP)
            if T.count_bars(content[s:e+1], e-s+1) >= T.BAR_THR]
    s, e = rows[0]
    sub = content[s:e+1]
    comps = T.components(sub)
    digits = [c for c in comps if c[5] >= 14 and c[5] <= 45 and c[5] > c[4] and c[4] >= 6]
    spans = [(d[0], d[2]) for d in digits]
    print(f"\n=== {os.path.basename(IMG)} 行0 y[{s}-{e}] 数字{len(digits)}个 ===")
    print("数字 x 范围(前8):", spans[:8])
    print("所有横线候选(w>10, h<=8):")
    for c in comps:
        if c[4] > 10 and c[5] <= 8 and c[4] > 2*c[5]:
            overlap = any(not (c[2] < s0 or c[0] > s1) for s0, s1 in spans)
            print(f"   x{c[0]}-{c[2]} y{c[1]}-{c[3]} w{c[4]} h{c[5]} 与数字重叠={overlap} "
                  f"{'(时值线)' if overlap else '(独立延音杠)'}")
