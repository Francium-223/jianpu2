# -*- coding: utf-8 -*-
"""直接测: 模型对行带的"音符/文字"判定。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import jp_transcribe as JP

def bands_of(page):
    arr = np.asarray(Image.open(page).convert("L"))
    content = arr < T.TOL
    out = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        for s, e in T.split_row_inner(content, s0, e0):
            sub = content[s:e + 1]
            st, hl = T.strip_hlines(sub)
            cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
            tl = [c for c in cs if c[5] >= 1.4 * c[4]]
            fr = (len(tl) / len(cs)) if cs else 0.0
            nl = sum(1 for h in hl if h[4] >= 8)
            acc = fr >= 0.85 or (len(tl) >= 6 and nl >= 1)
            if acc and fr < 0.85:
                out.append((s, e, fr, len(tl), nl, arr[s:e + 1]))
    return out

page = sys.argv[1]
items = bands_of(page)
print(f"{os.path.basename(page)}: 可疑行带 {len(items)} 个")
flags = JP._classify_bands([it[5] for it in items])
for (s, e, fr, nt, nl, g), f in zip(items, flags):
    print(f"  y={s:4d}-{e:4d} frac={fr:.2f} tall={nt:3d} 横线={nl:2d} -> 模型判: {'音符' if f else '文字'}")
