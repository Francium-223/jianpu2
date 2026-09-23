# -*- coding: utf-8 -*-
"""dump 若干谱的 '0' 块来源与几何: 分类器 rest vs 模型预测 0。"""
import os, sys
from collections import Counter
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from classify_block import classify_block

def analyze(img):
    arr = np.asarray(Image.open(img).convert("L"))
    content = arr < T.TOL
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    rest_crops = []   # classify_block 判 rest
    digit_crops = []  # classify_block 判 digit (可能模型判 0)
    for s, e in bands:
        sub = content[s:e + 1]
        stripped, hlines = T.strip_hlines(sub)
        cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
        tall = [c for c in cs if c[5] >= 1.4 * c[4]]
        frac = (len(tall) / len(cs)) if cs else 0.0
        if not (frac >= 0.85 or (len(tall) >= 6 and sum(1 for h in hlines if h[4] >= 8) >= 1)):
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
            if bt == "rest":
                rest_crops.append((crop.shape[0], crop.shape[1]))
            elif bt == "digit":
                big = [c for c in T.components(crop < T.TOL) if c[5] >= 12 and c[4] >= 4]
                if big and (not h_ref or max(c[5] for c in big) >= 0.8 * h_ref):
                    digit_crops.append((crop.shape[0], crop.shape[1]))
    return rest_crops, digit_crops

import glob
rs = Counter(); ds = Counter()
for d in glob.glob("images-prep/*/*/")[:30]:
    fs = glob.glob(os.path.join(d, "*.jpg"))
    if not fs:
        continue
    try:
        img = max(fs, key=os.path.getsize)
        if "__pg" in img:
            continue
        r, dd = analyze(img)
        for h, w in r: rs[(h, w)] += 1
        for h, w in dd: ds[(h, w)] += 1
    except Exception:
        pass
print("classify_block 判 rest 的块 (高,宽) 分布:")
for k, v in sorted(rs.items(), key=lambda x: -x[1])[:20]:
    print(f"  高{k[0]:3d} 宽{k[1]:3d}  x{v}")
print("\ndigit 块 (可能含模型判0) 尺寸分布:")
for k, v in sorted(ds.items(), key=lambda x: -x[1])[:15]:
    print(f"  高{k[0]:3d} 宽{k[1]:3d}  x{v}")
