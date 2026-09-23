# -*- coding: utf-8 -*-
"""看一眼第二轮(只跑 todo= 那批)的清洗结果, 人工过一遍改得对不对。"""
import csv
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

rows = list(csv.DictReader(open("train-work/title_fix2.tsv", encoding="utf-8"), delimiter="\t"))
ch = [r for r in rows if r["有变化"] == "1"]
same = [r for r in rows if r["有变化"] != "1"]
print(f"共 {len(rows)} 条: 有改动 {len(ch)}, 未改动 {len(same)}")
print("\n--- 有改动的全部列出(便于人工核):")
for i, r in enumerate(ch, 1):
    print(f"{i:3d}. {r['原始名'][:44]:<46} -> {r['模型曲名']}")
print("\n--- 模型认为原名已经干净的:")
for r in same[:40]:
    print(f"     {r['模型曲名'][:52]}")
