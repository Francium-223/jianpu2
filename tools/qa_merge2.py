# -*- coding: utf-8 -*-
"""确认含"词/曲"信息的同名歌仍保持独立(不被误并)。"""
import csv, sys
sys.path.insert(0, "tools"); sys.path.insert(0, "tools")
import os
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
rows = list(csv.DictReader(open("train-work/pick_best.tsv", encoding="utf-8"), delimiter="\t"))
print("含'童年'的归并组:")
for r in rows:
    if "童年" in r["dir"]:
        print(f"  {r['others']:>4} 他版 nline={r['nline']:>3}  {r['dir'][:54]}")
print("\n含'故乡'的归并组(抽查):")
n = 0
for r in rows:
    if "故乡" in r["dir"]:
        print(f"  {r['others']:>4} 他版 nline={r['nline']:>3}  {r['dir'][:54]}")
        n += 1
        if n >= 5:
            break
