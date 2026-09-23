# -*- coding: utf-8 -*-
"""dump blueberry 所有数字块: 高度 / y 位置 / 模型预测值, 定位 '?' 来源。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from classify_block import classify_block
import jp_transcribe as JP

img = r"images-prep/qupu123-crawl/Blue_Berry_Hill_鸟饭树山（蓝莓山）__qupu123-375493/002.jpg"
arr = np.asarray(Image.open(img).convert("L"))
content = arr < T.TOL

# 复刻 jp_transcribe 的切块(含 frac_abs + 高度门), 但记录每个块的几何
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

rows = []
for s, e in bands:
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
    tall = [c for c in cs if c[5] >= 1.4 * c[4]]
    frac = (len(tall) / len(cs)) if cs else 0.0
    if len(tall) < 4 and frac < 0.85:
        continue
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    h_ref = 0
    cs2 = [c for c in T.components(stripped) if 10 <= c[5] <= 45 and c[4] >= 3]
    tall2 = [c for c in cs2 if c[5] >= 1.4 * c[4]]
    if tall2:
        hs = sorted(c[5] for c in tall2)
        h_ref = hs[len(hs) // 2]
        dig = [c for c in tall2 if c[5] >= 0.8 * h_ref]
        if dig and be is None:
            be = (min(c[1] for c in dig), max(c[3] for c in dig))
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        bt = classify_block(crop)
        if bt != "digit":
            continue
        big = [c for c in T.components(crop < T.TOL) if c[5] >= 12 and c[4] >= 4]
        if not big:
            continue
        bh = max(c[5] for c in big)
        if h_ref and bh < 0.8 * h_ref:
            continue
        rows.append((s, ny0, crop, bh, h_ref))

print(f"数字块 {len(rows)}")
# 用模型批量识别
JP._init()
crops = [r[2] for r in rows]
nums = JP._digits_of_batch(crops, batch_size=8)
qmarks = []
for i, (s, ny0, crop, bh, h_ref) in enumerate(rows):
    v = nums[i]
    if v == "?":
        qmarks.append((s, ny0, bh, h_ref))
print(f"'?' 块 {len(qmarks)} 个:")
from collections import Counter
print("  按块高度分布:", Counter(bh for s, ny0, bh, h_ref in qmarks))
print("  按块高/行参考高比:", Counter(round(bh / h_ref, 2) for s, ny0, bh, h_ref in qmarks if h_ref))
print("\n  前 30 个 ? 块 (行带y, 块ny0, 块高, 参考高):")
for s, ny0, bh, h_ref in qmarks[:30]:
    print(f"    y={s:4d} ny0={ny0:3d} bh={bh:2d} h_ref={h_ref:2d}")
# 数字块高度总体分布
print("\n全部数字块高度分布:", Counter(bh for s, ny0, crop, bh, h_ref in rows))
