# -*- coding: utf-8 -*-
"""诊断: 前奏行(括号内、字号偏小)的连通域高度 vs 正文行, 看为什么前奏被读成休止符。"""
import sys, os
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

IMG = "images-prep/jianpucn-pop/富士山下(陈奕迅)__jianpucn-438812/001.jpg"
im = Image.open(IMG).convert("L")
arr = np.asarray(im)
content = arr < T.TOL
print(f"页 {im.size}")
for i, (s, e) in enumerate(T.fine_rows(content, T.ROW_GAP)):
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if c[4] >= 2]
    if not cs:
        continue
    hs = sorted(c[5] for c in cs)
    med = hs[len(hs) // 2]
    # 按管线的数字判据统计
    dg = [c for c in cs if c[5] >= 14 and c[5] <= 45 and c[5] > c[4] and c[4] >= 3 and c[5] < 3.5 * c[4]]
    print(f"  行 {i:2d} y={s:4d}-{e:4d} 连通域{len(cs):3d} 高度中位{med:3d} 最高{hs[-1]:3d} "
          f"数字判据通过{len(dg):3d}")
