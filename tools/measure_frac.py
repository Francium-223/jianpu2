# -*- coding: utf-8 -*-
"""量: 各谱的"前两个行带"里, frac(瘦高块占比)的分布 —— 为谱头过滤定阈值。

纯几何(CPU), 不加载模型。若"第一带 frac 低、第二带 frac 高"是普遍形态,
说明谱头确实单独成带、且 frac 能把它和音乐行分开。
"""
import glob
import os
import sys
from collections import Counter

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

N = int(sys.argv[1]) if len(sys.argv) > 1 else 200
files = sorted(f for f in glob.glob("batch-out/*.txt")
               if os.path.basename(f) not in ("progress.txt", "skipped.txt"))[:N]
print(f"抽样 {len(files)} 个谱")

b1 = Counter()      # 第一带 frac 分档
b2 = Counter()      # 第二带 frac 分档
pattern = Counter()
for f in files:
    name = os.path.basename(f)[:-4]
    d = next((x for x in glob.glob("images-prep/*/*")
              if os.path.isdir(x) and BT.safe_name(os.path.basename(x)) == name), None)
    if not d:
        continue
    try:
        p = BT.pick_page(d)
        im = Image.open(p).convert("L")
        if im.width > 2000:
            im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
        elif im.width < 950:
            im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
        g = np.asarray(im) < T.TOL
        bands = list(T.fine_rows(g, T.ROW_GAP))[:2]
        fr = []
        for s, e in bands:
            sub = g[s:e + 1]
            st, _ = T.strip_hlines(sub)
            cs = [x for x in T.components(st) if 10 <= x[5] <= 45 and x[4] >= 3]
            if not cs:
                fr.append(0.0); continue
            R = 1.15
            fr.append(sum(1 for c in cs if c[5] >= R * c[4]) / len(cs))
        if len(fr) < 2:
            continue
        b1[round(fr[0], 1)] += 1
        b2[round(fr[1], 1)] += 1
        if fr[0] < 0.6 <= fr[1]:
            pattern["第一带低(0.6以下) + 第二带高"] += 1
        elif fr[0] >= 0.6 and fr[1] >= 0.6:
            pattern["两带都高"] += 1
        else:
            pattern["其它"] += 1
    except Exception:
        continue

print("\n第一带 frac 分布:", dict(sorted(b1.items())))
print("第二带 frac 分布:", dict(sorted(b2.items())))
print("\n形态:", dict(pattern))
