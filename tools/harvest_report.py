# -*- coding: utf-8 -*-
"""报"歌手整页全谱"这一片抓了多少、其中多少是**新的**（不在现有语料里）。"""
import glob
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")

have = set()
for d in ("jianpu-db-out/scores", "batch-out", "batch-out-dup", "batch-out-bad",
          "batch-out-empty", "batch-out-suspect"):
    for f in glob.glob(d + "/*.txt"):
        have.add(os.path.basename(f)[:-4])

ART = {"1542": "张国荣", "414": "张学友", "855": "刘德华", "3246": "Beyond",
       "315": "陈奕迅", "3395": "王菲", "1165": "郁可唯", "600": "王力宏",
       "836": "任贤齐", "736": "汪苏泷", "468": "孙燕姿", "1542 ": "张国荣"}
tot_new = 0
for d in sorted(glob.glob("images-prep/jianpujia-art*")):
    sheets = [x for x in glob.glob(d + "/*") if os.path.isdir(x)]
    if not sheets:
        continue
    new = [s for s in sheets if os.path.basename(s) not in have]
    cid = os.path.basename(d).replace("jianpujia-art", "")
    print(f"  {ART.get(cid, cid):<8} {d.split('/')[-1]:<20} 谱 {len(sheets):>3}  其中新 {len(new):>3}")
    tot_new += len(new)
print(f"\n歌手整页全谱合计新增 {tot_new} 张")
