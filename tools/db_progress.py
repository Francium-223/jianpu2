# -*- coding: utf-8 -*-
"""统计 jianpu-db README 的转写进度(按作品)。"""
import re, sys
sys.stdout.reconfigure(encoding="utf-8")

lines = open("D:/Documents_D/jianpu-db/README.md", encoding="utf-8").read().splitlines()
print(f"{'作品':24s}{'总数':>5s}{'有旋律':>7s}{'缺':>5s}   完成度")
tot_all = has_all = miss_all = 0
for l in lines:
    if "scores/" not in l:
        continue
    name = re.sub(r"<abbr.*", "", l).strip().rstrip("：:").strip()
    n_miss = l.count("[⬛](scores/")
    n_has = len(re.findall(r"\[(?![⬛])(.)\]\(scores/", l))
    tot = n_has + n_miss
    if tot == 0:
        continue
    tot_all += tot; has_all += n_has; miss_all += n_miss
    pct = 100 * n_has / tot
    bar = "█" * int(pct / 10) + "░" * (10 - int(pct / 10))
    print(f"{name[:22]:24s}{tot:5d}{n_has:7d}{n_miss:5d}   {bar} {pct:.0f}%")
print("-" * 56)
print(f"{'合计':24s}{tot_all:5d}{has_all:7d}{miss_all:5d}   {100*has_all/tot_all:.0f}%")
