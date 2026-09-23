# -*- coding: utf-8 -*-
"""乱码 '?' 分布: 集中在少数谱还是普遍存在。"""
import glob, os, re, sys
from collections import Counter
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")
rows = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b.startswith("hot_"):
        continue
    tk = open(f, encoding="utf-8").read().split()
    notes = [t for t in tk if NOTE.match(t)]
    q = sum(1 for t in tk if "?" in t)
    if q:
        rows.append((q, len(notes), b))

rows.sort(reverse=True)
tot_q = sum(r[0] for r in rows)
print(f"含 '?' 的文件: {len(rows)} / 1375   (总 ? 数 {tot_q})")
print(f"占比: {100*len(rows)/1375:.0f}% 的谱受影响\n")

buckets = Counter()
for q, n, b in rows:
    if q == 1:
        buckets["1 个"] += 1
    elif q <= 3:
        buckets["2-3 个"] += 1
    elif q <= 10:
        buckets["4-10 个"] += 1
    elif q <= 50:
        buckets["11-50 个"] += 1
    else:
        buckets["50+ 个"] += 1
print("每个文件的 ? 数量分布:")
for k in ["1 个", "2-3 个", "4-10 个", "11-50 个", "50+ 个"]:
    print(f"  {k:9s} {buckets[k]:5d} 个文件")

print("\n? 最多的 15 个文件:")
for q, n, b in rows[:15]:
    print(f"  {q:4d} 个?  (共{n:4d}音)  {b[:66]}")

# ? 占该谱音符的比例(严重污染)
print("\n? 占音符比 >20% 的谱(严重污染):")
sev = [(q, n, b) for q, n, b in rows if n and q / (q + n) > 0.2]
print(f"  共 {len(sev)} 个")
for q, n, b in sorted(sev, key=lambda x: -x[0] / max(x[1], 1))[:10]:
    print(f"  {100*q/(q+n):4.0f}%  ({q}?/{n}音)  {b[:60]}")
