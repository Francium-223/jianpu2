# -*- coding: utf-8 -*-
"""快速判页: 用"墨密度"区分 简谱页(稀疏) vs 五线谱页(5条线+密集和弦, 墨多)。
同时对比 pick_page 的"最大文件"选择。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image

def ink(path, n=96):
    im = Image.open(path).convert("L")
    im = im.resize((n, int(n * im.height / im.width)))
    a = np.asarray(im, dtype=np.float32)
    return float((a < 170).mean())

dirs = sorted(glob.glob("images-prep/*/*/"))
print(f"目录 {len(dirs)}")
multi = 0
rows = []
for d in dirs:
    fs = sorted(f for f in glob.glob(os.path.join(d, "*.jpg")) if "__pg" not in os.path.basename(f))
    if len(fs) < 2:
        continue
    multi += 1
    info = []
    for f in fs:
        try:
            info.append((os.path.basename(f), ink(f), os.path.getsize(f)))
        except Exception:
            pass
    if not info:
        continue
    pick = max(info, key=lambda x: x[2])[0]
    sparse = min(info, key=lambda x: x[1])[0]
    rows.append((os.path.basename(d), pick, sparse, len(info)))

print(f"多页目录 {multi}")
same = sum(1 for _, p, s, _ in rows if p == s)
print(f"最大文件 vs 最稀疏(推测简谱页): 一致 {same}, 不一致 {multi-same} ({100*(multi-same)/max(multi,1):.0f}%)")
print("\n不一致示例(前 20):")
for name, p, s, n in rows:
    if p != s:
        print(f"  {name[:44]:46s} {n}页  最大={p}  最稀疏={s}")
print("\n一致示例(前 5):")
k = 0
for name, p, s, n in rows:
    if p == s:
        print(f"  {name[:44]:46s} {n}页  {p}")
        k += 1
        if k >= 5:
            break
import json
json.dump(rows, open("train-work/page_ink.json", "w", encoding="utf-8"), ensure_ascii=False)
