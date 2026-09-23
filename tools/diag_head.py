# -*- coding: utf-8 -*-
"""查 某谱 的谱头区边界: 打印所有行带的 frac/tall, 标出哪一行被判为"音乐起点"。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

kw = sys.argv[1]
hits = [p for p in glob.glob("images-prep/*/*") if kw in os.path.basename(p)]
if not hits:
    print("找不到"); sys.exit()
page = BT.pick_page(hits[0])
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
print(f"{os.path.basename(hits[0])}  图 {arr.shape[1]}x{arr.shape[0]}  行带 {len(bands)}")

first85 = first60 = -1
feats = []
for i, (s, e) in enumerate(bands):
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    c = [x for x in T.components(st) if 10 <= x[5] <= 50 and x[4] >= 4]
    tl = [x for x in c if x[5] >= 1.4 * x[4]]
    fr = (len(tl) / len(c)) if c else 0.0
    feats.append((s, e, len(c), len(tl), fr))
    if first85 < 0 and fr >= 0.85:
        first85 = i
    if first60 < 0 and (fr >= 0.85 or (fr >= 0.60 and len(tl) >= 8)):
        first60 = i
for i, (s, e, n, nt, fr) in enumerate(feats):
    tag = ""
    if i == first60:
        tag += "  <= 音乐起点(保守)"
    if i == first85:
        tag += "  <= 第一个frac>=0.85"
    if first60 >= 0 and i < first60:
        tag += "  [谱头区-丢]"
    print(f"  y={s:4d}-{e:4d} h={e-s+1:3d} n={n:3d} tall={nt:3d} frac={fr:.2f}{tag}")
