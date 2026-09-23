# -*- coding: utf-8 -*-
"""dump 指定 y 区间行带的连通域(高/宽/高宽比), 查为何被判"不够瘦高"。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

kid = sys.argv[1]
y0, y1 = int(sys.argv[2]), int(sys.argv[3])
hits = [p for p in glob.glob("images-prep/*/*") if os.path.basename(p).endswith(kid)]
page = BT.pick_page(hits[0])
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
sub = content[y0:y1 + 1]
st, hl = T.strip_hlines(sub)
cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
print(f"y={y0}-{y1}  n={len(cs)}")
for c in sorted(cs, key=lambda c: c[0]):
    print(f"  x=[{c[0]:4d},{c[2]:4d}] y=[{c[1]:3d},{c[3]:3d}] w={c[4]:3d} h={c[5]:3d} h/w={c[5]/max(c[4],1):.2f}"
          f"  {'瘦高' if c[5] >= 1.4 * c[4] else ''}")
print(f"横线 {len(hl)} 条: {[(h[0],h[4],h[5]) for h in sorted(hl,key=lambda z:z[0])]}")
