# -*- coding: utf-8 -*-
"""看 long_rows 高低两组的其他特征, 判断这个判据可靠不可靠。"""
import csv, statistics, sys
sys.stdout.reconfigure(encoding="utf-8")

rows = list(csv.DictReader(open("train-work/kind_feats.tsv", encoding="utf-8"), delimiter="\t"))
for r in rows:
    for k in ("long_rows", "groups", "ink", "note_blocks", "w", "h"):
        r[k] = float(r[k])

hi = [r for r in rows if r["long_rows"] >= 60]
lo = [r for r in rows if r["long_rows"] < 10]
print(f"long_rows>=60: {len(hi)}")
print("   墨密度中位", round(statistics.median(r["ink"] for r in hi), 3),
      "  note_blocks中位", statistics.median(r["note_blocks"] for r in hi))
print(f"long_rows<10: {len(lo)}")
print("   墨密度中位", round(statistics.median(r["ink"] for r in lo), 3),
      "  note_blocks中位", statistics.median(r["note_blocks"] for r in lo))
print("\n>=60 样例:")
for r in hi[:8]:
    print(f"   lr={r['long_rows']:.0f} ink={r['ink']:.3f} blocks={r['note_blocks']:.0f} {r['dir'][:36]}")
print("<10 样例:")
for r in lo[:8]:
    print(f"   lr={r['long_rows']:.0f} ink={r['ink']:.3f} blocks={r['note_blocks']:.0f} {r['dir'][:36]}")
# 墨密度分布
print("\n墨密度分布(全部):")
import collections
c = collections.Counter(round(r["ink"], 1) for r in rows)
for k in sorted(c):
    print(f"   {k}: {c[k]}")
