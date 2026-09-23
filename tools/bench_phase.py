# -*- coding: utf-8 -*-
"""测单谱耗时拆解: 几何(切块) vs 模型前向。"""
import os, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
import classify_block as CB
import jp_transcribe as JP

IMG = "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr = np.asarray(Image.open(IMG).convert("L"))
content = arr < T.TOL

t0 = time.time()
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
t_rows = time.time() - t0

blocks = []
t0 = time.time()
for s, e in bands:
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        bt = CB.classify_block(crop)
        blocks.append((crop, bt))
t_geo = time.time() - t0

digits = [c for c, bt in blocks if bt == "digit"]
t0 = time.time()
JP._init()
t_load = time.time() - t0
t0 = time.time()
_ = JP._digits_of_batch(digits)
t_model = time.time() - t0

print(f"行切分 {t_rows:.2f}s | 切块 {t_geo:.2f}s | 模型加载 {t_load:.1f}s | 模型前向 {t_model:.2f}s")
print(f"块数 {len(blocks)} (digit {len(digits)})")
print(f"单谱(不含加载) 几何 {t_rows+t_geo:.2f}s + 模型 {t_model:.2f}s = {t_rows+t_geo+t_model:.2f}s")
