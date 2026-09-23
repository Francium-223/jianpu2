# -*- coding: utf-8 -*-
"""诊断: 将进酒里被识别为 x 的块, 其 btype 与连通域尺寸到底是什么。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from classify_block import classify_block

src = sorted(glob.glob("images-prep/qupu123-crawl/将进酒__qupu123-382162/*.jpg"),
             key=os.path.getsize)[-1]
arr = np.asarray(Image.open(src).convert("L"))
content = arr < T.TOL

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

from collections import Counter
cnt = Counter()
shown = 0
for s, e in bands:
    sub = content[s:e + 1]
    if T.count_bars(sub, e - s + 1) < T.BAR_THR:
        continue
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        bt = classify_block(crop)
        comps = T.components(crop < T.TOL)
        big = [c for c in comps if c[5] >= 12 and c[4] >= 4]
        cnt[(bt, len(big) > 0)] += 1
        if bt == "digit" and shown < 12:
            shown += 1
            top = sorted(comps, key=lambda c: -c[5])[:3]
            dims = " ".join(f"[w{c[4]} h{c[5]}]" for c in top)
            print(f"块 x[{nx0},{nx1}] y[{ny0},{ny1}] crop={crop.shape} bt={bt} 大连通域={len(big)}  top3: {dims}")

print("\n=== (btype, 是否有大连通域) 计数 ===")
for k, v in cnt.most_common():
    print(f"  btype={k[0]:8s} 有大连通域={k[1]!s:5s} : {v} 个块")
