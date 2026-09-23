# -*- coding: utf-8 -*-
"""诊断歌词泄漏: 逐行带打印 frac/tall/是否通过行带过滤, 以及每行带有多少块会送模型。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from classify_block import classify_block

img = sys.argv[1]
arr = np.asarray(Image.open(img).convert("L"))
content = arr < T.TOL
print(f"图 {os.path.basename(img)} {arr.shape[1]}x{arr.shape[0]}")

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

for s, e in bands:
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
    tall = [c for c in cs if c[5] >= 1.4 * c[4]]
    frac = (len(tall) / len(cs)) if cs else 0.0
    passed = not (len(tall) < 4 and frac < 0.85)
    if not passed and len(cs) < 3:
        continue
    # 若通过, 统计会送模型的块数
    n_send = 0
    if passed:
        row_gray = arr[s:e + 1]
        be = Q.bar_extent(sub)
        h_ref = 0
        cs2 = [c for c in T.components(stripped) if 10 <= c[5] <= 45 and c[4] >= 3]
        tall2 = [c for c in cs2 if c[5] >= 1.4 * c[4]]
        if tall2:
            hs = sorted(c[5] for c in tall2)
            h_ref = hs[len(hs)//2]
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
            if h_ref and max(c[5] for c in big) < 0.8 * h_ref:
                continue
            n_send += 1
    mark = "通过" if passed else "丢弃"
    print(f"y={s:4d}-{e:4d} h={e-s+1:3d} n={len(cs):3d} tall={len(tall):3d} frac={frac:.2f} "
          f"{mark} 送模型={n_send:3d}")
