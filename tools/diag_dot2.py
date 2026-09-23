# -*- coding: utf-8 -*-
"""dump 前奏行带的全部连通域(原始 + strip_hlines 后), 查附点为何没被收纳。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

page = "images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003__pg0.jpg"
if not os.path.exists(page):
    import batch_transcribe as BT
    BT.split_pages("images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003.jpg")
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL

s, e = 284, 346
sub = content[s:e + 1]
print(f"行带 y={s}-{e} h={e-s+1}  图宽 {sub.shape[1]}")

raw = T.components(sub)
print(f"\n原始连通域 {len(raw)} 个 (按 x 排序):")
for c in sorted(raw, key=lambda c: c[0]):
    print(f"  x=[{c[0]:4d},{c[2]:4d}] y=[{c[1]:3d},{c[3]:3d}]  w={c[4]:3d} h={c[5]:3d}  "
          f"aspect={c[4]/max(c[5],1):.2f}")

stripped, hlines = T.strip_hlines(sub)
print(f"\nstrip_hlines 后连通域 {len(T.components(stripped))} 个; 抹掉的横线 {len(hlines)} 条:")
for h in sorted(hlines, key=lambda c: c[0]):
    print(f"  横线 x=[{h[0]:4d},{h[2]:4d}] y=[{h[1]:3d},{h[3]:3d}] w={h[4]:3d} h={h[5]:3d}")
