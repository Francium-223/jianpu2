# -*- coding: utf-8 -*-
"""诊断 行1 的 bar_extent(音符行底) 与 块分布: 歌词是否被并入."""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T, transcribe_qwen as Q

arr = np.asarray(Image.open("train-work/gt/兄弟抱一下.jpg").convert("L"))
content = arr < T.TOL
rows = [(s, e) for s, e in T.fine_rows(content, T.ROW_GAP)
        if T.count_bars(content[s:e+1], e-s+1) >= T.BAR_THR]
s, e = rows[0]
sub = content[s:e+1]
be = Q.bar_extent(sub)
print(f"行1 y[{s}-{e}] h={e-s+1}  bar_extent={be}")
# 每行暗像素数(看歌词行位置)
prof = sub.sum(axis=1)
print("行内暗像素分布(每5行):", [int(prof[i]) for i in range(0, len(prof), 5)])
regs = T.crop_note_regions(sub)
print("块数", len(regs))
# 块 ny0 分布(低于 bbot 的块 = 歌词)
below = [r for r in regs if r[2] > (be[1] if be else 1e9)]
print(f"ny0 > bbot 的块(应被bound_to_note_row排除): {len(below)}")
