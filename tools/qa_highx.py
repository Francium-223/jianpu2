# -*- coding: utf-8 -*-
"""QA: 找"念白 x 占比异常高"的谱 —— 多半是错谱(歌词/五线谱漏过过滤)。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

rows = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b in ("progress.txt", "skipped.txt"):
        continue
    t = open(f, encoding="utf-8").read().split()
    if len(t) < 20:
        continue
    nx = sum(1 for x in t if "x" in x)
    n0 = sum(1 for x in t if x.endswith("0") or x == "0")
    rows.append((nx / len(t), nx, n0, len(t), b))

rows.sort(reverse=True)
hi = [r for r in rows if r[0] >= 0.30]
print(f"转写 {len(rows)} 个; x 占比 >=30% 的: {len(hi)}")
print(f"  这批次合计 x {sum(r[1] for r in hi)}, 0 {sum(r[2] for r in hi)}")
print("\n最高的 12 个:")
for r, nx, n0, n, b in rows[:12]:
    print(f"  x={r*100:5.1f}%  x{nx:3d} 0{n0:3d} 共{n:4d}  {b[:46]}")
# 全库 x 占比
tot = sum(r[3] for r in rows); tx = sum(r[1] for r in rows)
print(f"\n全库: {tot} token, x {tx} ({100*tx/max(tot,1):.1f}%)")
