# -*- coding: utf-8 -*-
"""诊断 兄弟抱一下 的行划分: 谱头是否并入第一行."""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T

arr = np.asarray(Image.open("train-work/gt/兄弟抱一下.jpg").convert("L"))
content = arr < T.TOL
print("ROW_GAP", T.ROW_GAP, "BAR_THR", T.BAR_THR, "图片高", arr.shape[0])
rows = T.fine_rows(content, T.ROW_GAP)
print("行数", len(rows))
for i, (s, e) in enumerate(rows[:8]):
    sub = content[s:e+1]
    bars = T.count_bars(sub, e - s + 1)
    tag = "NOTE-ROW" if bars >= T.BAR_THR else "skip"
    print(f"  行{i}: y[{s}-{e}] h={e-s+1} bars={bars} {tag}")
