# -*- coding: utf-8 -*-
"""打印问候歌每个行带的判据(瘦高块占比 / 横线数 / 小节线数), 看哪些行被放行。"""
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
print(f"图 {arr.shape[1]}x{arr.shape[0]}\n")

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
print(f"行带 {len(bands)} 个\n")
print(f"{'y0':>5} {'y1':>5} {'h':>4} {'frac':>6} {'横线':>4} {'节线':>4}  放行?")
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    nb = T.count_bars(sub, e - s + 1)
    ok = (frac >= 0.6) or (len(hl) >= 2)
    print(f"{s:5d} {e:5d} {e-s+1:4d} {frac:6.2f} {len(hl):4d} {nb:4d}  {'放行' if ok else '丢弃'}")
