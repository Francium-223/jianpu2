# -*- coding: utf-8 -*-
"""dump 指定谱页的行带特征。用法: py tools/dump_bands.py <图片路径或ID>"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

arg = sys.argv[1]
if os.path.exists(arg):
    page = arg
else:
    hits = [p for p in glob.glob("images-prep/*/*") if os.path.basename(p).endswith(arg)]
    page = BT.pick_page(hits[0])
    pages = BT.split_pages(page)
    print("切页:", [os.path.basename(p) for p in pages])
    page = pages[0]
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
print(f"{os.path.basename(page)}  {arr.shape[1]}x{arr.shape[0]}")
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
print(f"行带 {len(bands)} 个")
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    tl = [c for c in cs if c[5] >= 1.4 * c[4]]
    fr = (len(tl) / len(cs)) if cs else 0.0
    nl = sum(1 for h in hl if h[4] >= 8)
    acc = fr >= 0.85 or (len(tl) >= 6 and nl >= 1)
    print(f"  y={s:4d}-{e:4d} h={e-s+1:4d} n={len(cs):3d} tall={len(tl):3d} frac={fr:.2f} "
          f"横线={nl:3d} {'接受' if acc else '丢弃'}")
