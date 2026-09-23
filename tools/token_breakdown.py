# -*- coding: utf-8 -*-
"""token 构成统计: 数字/0/x/-/其他。"""
import glob, os, sys
from collections import Counter
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

c = Counter()
for f in glob.glob("batch-out/*.txt"):
    if os.path.basename(f) in ("progress.txt", "skipped.txt"):
        continue
    for t in open(f, encoding="utf-8").read().split():
        core = t.lstrip("qsdh,").rstrip("'.")
        if not core:
            c["(空)"] += 1; continue
        if core == "?":
            c["?"] += 1
        elif core == "x":
            c["x念白"] += 1
        elif core == "0":
            c["0休止"] += 1
        elif core == "-":
            c["-杠"] += 1
        elif core[-1] in "1234567":
            c["数字1-7"] += 1
        else:
            c["其他:" + core] += 1
print("token 构成:")
for k, v in sorted(c.items(), key=lambda x: -x[1]):
    print(f"  {k:14s} {v:7d}  ({100*v/sum(c.values()):.1f}%)")
print("合计", sum(c.values()))
