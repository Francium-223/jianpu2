# -*- coding: utf-8 -*-
"""量化"胜出者被自己搬走"的丢歌 bug:
  A) kind2.tsv 里同一目录是否有多行(多页谱 -> 每页一行)
  B) pick_best.tsv 选中的 dir 里, 有多少当前躺在 batch-out-dup(即被误搬)
"""
import csv
import glob
import io
import os
import sys
from collections import Counter

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

rows = list(csv.DictReader(io.open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
c = Counter(r["dir"] for r in rows)
multi = {k: v for k, v in c.items() if v > 1}
print(f"A) kind2.tsv 共 {len(rows)} 行 / {len(c)} 个目录; **有多行的目录 {len(multi)} 个**")
print(f"   多余行合计 {sum(v - 1 for v in multi.values())}")
ex = [k for k in multi if "铁血丹心" in k]
print(f"   铁血丹心 相关: " + str({k: multi[k] for k in ex}))
print("   多行示例: " + " | ".join(f"{k[:34]}x{v}" for k, v in list(multi.items())[:5]))

sel = {}
for line in io.open("train-work/pick_best.tsv", encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 2 and p[0] != "title":
        sel[p[1]] = p[0]

have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
dup = {os.path.basename(f)[:-4] for f in glob.glob("batch-out-dup/*.txt")}
lost = [d for d in sel if d not in have and d in dup]
print(f"\nB) pick_best 选中 {len(sel)} 首")
print(f"   仍在 batch-out: {sum(1 for d in sel if d in have)}")
print(f"   **被误搬进 batch-out-dup: {len(lost)}**")
missing_all = [d for d in sel if d not in have and d not in dup]
print(f"   两边都没有(可能进了 -bad/-empty/-suspect): {len(missing_all)}")
for d in lost[:20]:
    print(f"      {sel[d][:16]:<18} {d[:52]}")

io.open("train-work/lost_winners.txt", "w", encoding="utf-8").write("\n".join(lost) + "\n")
print(f"\n写出 train-work/lost_winners.txt ({len(lost)} 行)")
