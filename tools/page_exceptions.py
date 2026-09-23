# -*- coding: utf-8 -*-
"""找出 qupu123 多页目录里几何最佳页不是 002.jpg 的例外, 看它们的 002 是什么。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

def score_fast(path, scale=0.3):
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
print("例外目录 (几何最佳页 != 002.jpg):\n")
for d in multi:
    fs = sorted(f for f in glob.glob(os.path.join(d, "*.jpg")) if "__pg" not in os.path.basename(f))
    sc = []
    for f in fs:
        try: sc.append((f, score_fast(f)))
        except Exception: sc.append((f, -1))
    geo = max(sc, key=lambda x: x[1])
    gname = os.path.basename(geo[0])
    if gname != "002.jpg":
        name = os.path.basename(d)
        # 修复 mojibake
        try: name = name.encode("latin-1").decode("utf-8")
        except Exception: pass
        print(f"{name[:40]}")
        for f, n in sc:
            print(f"    {os.path.basename(f):12s} 分{n}")
        break
