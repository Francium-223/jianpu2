# -*- coding: utf-8 -*-
"""诊断: 连音线/圆滑线在几何上是哪些连通域 —— 它们被 strip_hlines 当成"细横线"剥掉了,
需要区分「时值线(在数字下方)」与「连音线/圆滑线(通常在数字上方)」。
纯 CPU, 用 GT 图(人手写的谱, 已知有 ( ) 和 ~)。
"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

IMG = "train-work/gt/兄弟抱一下.jpg"
im = Image.open(IMG).convert("L")
if im.width > 2000:
    im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
c = np.asarray(im) < T.TOL
print(f"图 {im.size}")

for bi, (s, e) in enumerate(T.fine_rows(c, T.ROW_GAP)):
    sub = c[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [x for x in T.components(st) if 12 <= x[5] <= 45]
    if len(cs) < 4:
        continue
    # 数字的 y 范围
    ys = sorted(x[1] for x in cs) + sorted(x[3] for x in cs)
    top = min(x[1] for x in cs); bot = max(x[3] for x in cs)
    print(f"\n行 {bi} y={s}-{e}  数字 {len(cs)} 个, 数字带 y=[{top},{bot}]")
    print(f"  被剥掉的细横线 {len(hl)} 条:")
    for h in sorted(hl, key=lambda z: z[0])[:12]:
        # 判断在数字上方还是下方
        where = "上方(可能是连音线/圆滑线)" if h[3] <= top + 2 else ("下方(时值线)" if h[1] >= bot - 2 else "重叠")
        print(f"    x=[{h[0]:4d},{h[2]:4d}] y=[{h[1]:3d},{h[3]:3d}] w={h[4]:3d} h={h[5]}  {where}")
    if bi >= 3:
        break
