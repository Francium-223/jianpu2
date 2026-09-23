# -*- coding: utf-8 -*-
"""收尾抢救: ①找不到旧值的条目**退回原始名**(原始名本身就是歌名, 如《爱》《你》)
②剩下两个"啊，草原"条目做精确修正。
用法: py -3.13 tools/recover_round3b.py [--dry]
"""
import csv
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DRY = "--dry" in sys.argv
CLEAN = "train-work/title_clean.tsv"

rows = {}
with open(CLEAN, encoding="utf-8") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        rows[r["目录名"]] = dict(r)

# ① 找不到旧值的: 退回原始名(并标记"没有变化", 重建时就会用原始名)
n_rev = 0
for d, r in rows.items():
    if r.get("原文输出") == "recovered-unknown":
        r["模型曲名"] = r["原始名"]
        r["有变化"] = "0"
        r["原文输出"] = "reverted-to-original"
        n_rev += 1

# ② 剩下带"词…曲"署名残留的"啊，草原" -> 啊，草原
n_fix = 0
for d, r in rows.items():
    if r["原始名"].startswith("啊，草原") and r.get("模型曲名", "").startswith("啊，草原"):
        r["模型曲名"] = "啊，草原"
        r["有变化"] = "1"
        r["原文输出"] = "round3-manual-exact"
        n_fix += 1
        print(f"  精确修正 {r['原始名'][:40]} -> 啊，草原")

print(f"退回原始名 {n_rev} 条, 精确修正 {n_fix} 条")
if DRY:
    sys.exit(0)
with open(CLEAN, "w", encoding="utf-8") as f:
    f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
    for r in rows.values():
        f.write("\t".join(str(r.get(c, "")).replace("\t", " ") for c in
                          ("目录名", "原始名", "模型曲名", "有变化", "原文输出")) + "\n")
print(f"-> {CLEAN}")
