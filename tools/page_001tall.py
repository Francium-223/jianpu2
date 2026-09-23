# -*- coding: utf-8 -*-
"""检查 45 个"001是整谱且有002"的 qupu123 目录: 001 是真简谱页还是高标题条?"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

def score(path, scale=0.3):
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

n = 0
for d in glob.glob("images-prep/qupu123-crawl/*/"):
    f1 = os.path.join(d, "001.jpg"); f2 = os.path.join(d, "002.jpg")
    if not (os.path.exists(f1) and os.path.exists(f2)):
        continue
    try:
        w, h = Image.open(f1).size
    except Exception:
        continue
    if h <= 100:
        continue
    n += 1
    try:
        s1, s2 = score(f1), score(f2)
    except Exception:
        continue
    name = os.path.basename(d)
    try: name = name.encode("latin-1").decode("utf-8")
    except Exception: pass
    tag = "001更像简谱(会错)" if s1 > s2 else "002更像简谱(对)"
    print(f"{name[:30]:32s} 001={s1:4d} 002={s2:4d}  {tag}")
print(f"\n共 {n} 个")
