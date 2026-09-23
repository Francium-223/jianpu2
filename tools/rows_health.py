# -*- coding: utf-8 -*-
"""统计: 全量谱里 fine_rows 行带划分的质量分布(行带数越少 = 越可能划分失败)。"""
import glob, os, sys
from collections import Counter
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

dirs = [d for d in glob.glob("images-prep/*/*") if os.path.isdir(d)]
print(f"谱目录: {len(dirs)}")

dist = Counter()
bad = []
for d in dirs:
    fs = sorted(glob.glob(os.path.join(d, "*.jpg")), key=os.path.getsize)
    if not fs:
        continue
    try:
        arr = np.asarray(Image.open(fs[-1]).convert("L"))
        content = arr < T.TOL
        raw = T.fine_rows(content, T.ROW_GAP)
        n = len(raw)
        dist[min(n, 6)] += 1
        if n <= 2:
            bad.append((n, os.path.basename(d)[:50]))
    except Exception:
        continue

print("\nfine_rows 行带数分布:")
for k in sorted(dist):
    label = f"{k} 个" if k < 6 else "6+ 个"
    print(f"  {label:6s} {dist[k]:5d} 个谱")

n_bad = sum(dist[k] for k in dist if k <= 2)
n_all = sum(dist.values())
print(f"\n行带数 <=2 (划分失败风险): {n_bad} / {n_all}  ({100*n_bad/max(n_all,1):.0f}%)")
print("\n行带数 <=2 的谱(前 15):")
for n, b in sorted(bad, key=lambda x: x[0])[:15]:
    print(f"  {n} 行带  {b}")
