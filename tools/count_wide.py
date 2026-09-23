# -*- coding: utf-8 -*-
"""统计: 批次里各谱被挑中的页有多宽, 有多少超过阈值(绝对像素阈值会失效)。"""
import glob, json, os, sys
from collections import Counter
sys.path.insert(0, "tools"); sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

ranked = sorted(glob.glob("rank-out/ranked*.jsonl"))
rows = []
for rf in ranked:
    for l in open(rf, encoding="utf-8"):
        try:
            rows.append(json.loads(l))
        except Exception:
            pass
rows.sort(key=lambda r: r.get("play", 0), reverse=True)
seen, dirs = set(), []
for r in rows:
    d = os.path.dirname(r["img"])
    if d in seen:
        continue
    seen.add(d)
    dirs.append(d)
dirs = dirs[:1531]

buckets = Counter()
wide = []
for d in dirs:
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        w, h = Image.open(p).size
    except Exception:
        continue
    b = (w // 500) * 500
    buckets[b] += 1
    if w > 2400:
        wide.append((os.path.basename(d), w, h))
print("被挑页宽度分布:")
for k in sorted(buckets):
    print(f"  {k}-{k+500}: {buckets[k]}")
print(f"\n宽度 > 2400 的谱: {len(wide)}")
for n, w, h in wide[:15]:
    print(f"   {w}x{h}  {n[:46]}")
