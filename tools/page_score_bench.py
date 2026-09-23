# -*- coding: utf-8 -*-
"""判定: qupu123 多页目录里, 几何简谱分最高的页是不是总是 002.jpg? 计时两种缩放。"""
import glob, os, sys, time
from collections import Counter
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

def score_fast(path, scale):
    im = Image.open(path).convert("L")
    w, h = int(im.width * scale), int(im.height * scale)
    arr = np.asarray(im.resize((w, h)))
    content = arr < T.TOL
    ndig = 0
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        for s, e in T.split_row_inner(content, s0, e0):
            sub = content[s:e + 1]
            stripped, _ = T.strip_hlines(sub)
            cs = [c for c in T.components(stripped) if 8 <= c[5] <= 50 and c[4] >= 3]
            ndig += sum(1 for c in cs if c[5] >= 1.3 * c[4])
    return ndig

dirs = sorted(glob.glob("images-prep/qupu123-crawl/*/"))
multi = [d for d in dirs if len([f for f in glob.glob(os.path.join(d, "*.jpg")) if "__pg" not in os.path.basename(f)]) >= 2]

for scale in (0.3, 0.2):
    t0 = time.time(); bestnames = Counter(); mism = 0; tot = 0
    for d in multi[:80]:
        fs = sorted(f for f in glob.glob(os.path.join(d, "*.jpg")) if "__pg" not in os.path.basename(f))
        sc = []
        for f in fs:
            try: sc.append((f, score_fast(f, scale)))
            except Exception: sc.append((f, -1))
        if not sc: continue
        tot += 1
        geo = max(sc, key=lambda x: x[1])
        size = max(sc, key=lambda x: os.path.getsize(x[0]))
        bestnames[os.path.basename(geo[0])] += 1
        if os.path.basename(geo[0]) != os.path.basename(size[0]):
            mism += 1
    el = time.time() - t0
    print(f"scale={scale}: {el/max(tot,1):.2f}s/目录, 不一致 {mism}/{tot}")
    print(f"  几何最佳页文件名分布: {dict(bestnames.most_common(8))}")
