# -*- coding: utf-8 -*-
"""抽查: 清名是否真的落到 scores(文件名 + title= 一致), 以及 todo= 标记的写法。"""
import csv
import glob
import os
import random
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
from to_jianpu_db import load_clean_titles_soft

CLEAN = load_clean_titles_soft()
print(f"清名表 {len(CLEAN)} 条")

scores = {}
for f in glob.glob("jianpu-db-out/scores/*.txt"):
    try:
        head = open(f, encoding="utf-8", errors="replace").read(600)
    except Exception:
        continue
    m = re.search(r"^title=(.*)$", head, re.M)
    scores[os.path.basename(f)[:-4]] = (m.group(1).strip() if m else "")

print(f"scores {len(scores)} 份")
hit = 0
random.seed(11)
sample = random.sample(list(CLEAN.items()), 12)
for full, clean in sample:
    safe = re.sub(r'[\\/:*?"<>|\s]+', "_", clean).strip("_")[:60]
    ok = safe in scores and scores[safe] == clean
    if ok:
        hit += 1
    print(f"  {'✓' if ok else '✗'} {full[:38]:<40} -> 期望 {clean!r}  文件里 title={scores.get(safe)!r}")
print(f"抽样 {len(sample)} 条, 清名正确落地 {hit}")

# todo= 标记的写法
n = 0
for f in glob.glob("jianpu-db-out/scores/*.txt"):
    t = open(f, encoding="utf-8", errors="replace").read(1200)
    if "todo=" in t:
        print("\ntodo= 样例:", os.path.basename(f))
        for ln in t.splitlines():
            if ln.startswith(("title=", "source=", "todo=", "preferred=")):
                print("   " + ln)
        n += 1
        if n >= 2:
            break
