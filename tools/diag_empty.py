# -*- coding: utf-8 -*-
"""诊断 v2: 完整复刻 jp_transcribe 的切块路径(含 bound_to_note_row), 逐行带打印。
纯几何, 不加载模型。"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
import classify_block as CB

img = sys.argv[1]
arr = np.asarray(Image.open(img).convert("L"))
content = arr < T.TOL
print(f"图: {os.path.basename(img)}  {arr.shape[1]}x{arr.shape[0]}")
if len(sys.argv) > 2:
    thr = float(sys.argv[2])
else:
    thr = 0.85

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
print(f"行带 {len(bands)} 个 (阈值 {thr})\n")

acc = rej = 0
for s, e in bands:
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    n_tall = sum(1 for c in cs if c[5] >= 1.4 * c[4] and c[5] >= 14)
    ok = frac >= thr
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    nd = ndash = 0
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        bt = CB.classify_block(crop)
        if bt == "dash":
            ndash += 1
        elif bt == "digit":
            if [c for c in T.components(crop < T.TOL) if c[5] >= 12 and c[4] >= 4]:
                nd += 1
    if ok:
        acc += nd
    else:
        rej += nd
    print(f"y={s:4d}-{e:4d} h={e-s+1:3d} n={len(cs):3d} frac={frac:.2f} tall={n_tall:3d} "
          f"{'接受' if ok else '**丢弃**'} 生产digit={nd:3d} dash={ndash:3d} hl={len(hlines)}")
print(f"\n接受行 digit={acc}  **被丢行 digit={rej}**")
