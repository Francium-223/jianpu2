# -*- coding: utf-8 -*-
"""看一眼曲名清洗的结果(给人报告的样例)。"""
import csv
import os
import random
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

rows = list(csv.DictReader(open("train-work/title_clean.tsv", encoding="utf-8"), delimiter="\t"))
ch = [r for r in rows if r["有变化"] == "1"]
q = [r for r in rows if r["模型曲名"] == "?"]
print(f"总 {len(rows)}  有改动 {len(ch)}  未通过校验 {len(q)}")
if q:
    print("未通过校验的:")
    for r in q[:5]:
        print(f"   原始={r['原始名'][:50]!r}  原文输出={r['原文输出'][:60]!r}")

random.seed(7)
print("\n--- 改动样例(随机 12 条)")
for r in random.sample(ch, 12):
    print(f"   {r['原始名'][:52]:<54} -> {r['模型曲名']}")

print("\n--- 模型压得最多的 6 条")
for r in sorted(ch, key=lambda x: -len(x["原始名"]))[:6]:
    print(f"   ({len(r['原始名'])}字) {r['原始名'][:60]:<62} -> {r['模型曲名']}")

print("\n--- 含 [英]/[日] 语言标记的(用户要求保留)")
n = 0
for r in ch:
    if r["模型曲名"].startswith("[") :
        print(f"   {r['原始名'][:50]:<52} -> {r['模型曲名']}")
        n += 1
        if n >= 5:
            break

print("\n--- 模型输出与原名相同的(即认为原名已干净)")
print(f"   {len(rows) - len(ch) - len(q)} 条")
