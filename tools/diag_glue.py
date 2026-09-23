# -*- coding: utf-8 -*-
"""dump: blueberry 各粘连行带里, 瘦高块(tall) 与 全部块的 y 位置, 找音符行/歌词行分界。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

img = r"images-prep/qupu123-crawl/Blue_Berry_Hill_鸟饭树山（蓝莓山）__qupu123-375493/002.jpg"
arr = np.asarray(Image.open(img).convert("L"))
content = arr < T.TOL
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

for s, e in bands:
    sub = content[s:e + 1]
    if e - s + 1 < 50:
        continue
    stripped, hlines = T.strip_hlines(sub)
    cs = T.components(stripped)
    tall = sorted([c for c in cs if 10 <= c[5] <= 50 and c[4] >= 4 and c[5] >= 1.4 * c[4]],
                  key=lambda c: c[1])
    if len(tall) < 5:
        continue
    print(f"\n=== 行带 y={s}-{e} h={e-s+1} 全块{len(cs)} 瘦高{len(tall)} ===")
    # 打印瘦高块的 y-top..y-bottom (相对行带) 和 宽高
    ys = [c[1] - s for c in tall]
    print("  瘦高块 y-top(相对):", ys)
    print("  瘦高块 y-bot(相对):", [c[3] - s for c in tall])
    print("  瘦高块 (h,w):", [(c[5], c[4]) for c in tall])
    # hlines 位置
    if hlines:
        print("  横线 y(相对):", sorted(h[1] - s for h in hlines))
