# -*- coding: utf-8 -*-
"""对比 dump: 标题/署名行带 vs 真音符行带 的连通域特征, 找可区分的判据。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

page = "images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003__pg0.jpg"
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

def feats(s, e):
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
    tall = [c for c in cs if c[5] >= 1.4 * c[4]]
    frac = (len(tall) / len(cs)) if cs else 0.0
    hs = sorted(c[5] for c in tall)
    import statistics
    med = statistics.median(hs) if hs else 0
    # 高度一致性: 有多少瘦高块的高度在中位数 ±12% 内
    unif = (sum(1 for h in hs if abs(h - med) <= 0.12 * med) / len(hs)) if hs else 0.0
    # 宽高比分布
    return cs, tall, hlines, frac, med, unif

for s, e in bands:
    cs, tall, hlines, frac, med, unif = feats(s, e)
    if not cs:
        continue
    acc = frac >= 0.85 or (len(tall) >= 6 and sum(1 for h in hlines if h[4] >= 8) >= 1)
    hs = sorted(c[5] for c in tall)
    print(f"y={s:4d}-{e:4d} h={e-s+1:3d} n={len(cs):3d} tall={len(tall):3d} frac={frac:.2f} "
          f"高一致={unif:.2f} 横线={len(hlines):2d} {'接受' if acc else '丢弃'}")
    print(f"        瘦高块高度={hs}")
