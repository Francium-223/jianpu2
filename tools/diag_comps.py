# -*- coding: utf-8 -*-
"""打印问候歌第一行所有连通域的 bbox/尺寸, 确认下划线是否与数字粘连。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
print(f"图 {arr.shape[1]}x{arr.shape[0]}")

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

# 第一行"有音符"的带
for s, e in bands:
    sub = content[s:e + 1]
    nb = T.count_bars(sub, e - s + 1)
    if nb < T.BAR_THR:
        continue
    print(f"\n=== 行带 y[{s},{e}] h={e-s+1} 小节线={nb} ===")
    comps = sorted(T.components(sub), key=lambda c: c[0])
    print(f"连通域 {len(comps)} 个:")
    for c in comps[:26]:
        x0, y0, x1, y1, w, h = c[:6]
        kind = "数字" if (14 <= h <= 45 and h > w and w >= 6) else ("细横线" if (h <= 6 and w >= 8 and w >= 2*h) else "??")
        print(f"   x[{x0:3d},{x1:3d}] y[{y0:3d},{y1:3d}]  w={w:3d} h={h:3d}  {kind}")
    strip, lines = T.strip_hlines(sub)
    print(f"strip_hlines 抹掉横线 {len(lines)} 条")
    for c in lines[:8]:
        print(f"   横线 x[{c[0]},{c[2]}] y[{c[1]},{c[3]}] w={c[4]} h={c[5]}")
    break
