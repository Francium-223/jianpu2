# -*- coding: utf-8 -*-
"""复核"回收候选"在 batch-out / -dup 里的实况(哪个目录、多少音符)。"""
import io
import os
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DIG = "1234567"
names = [l.split("\t")[0] for l in io.open("train-work/readmit_applied.log", encoding="utf-8") if l.strip()]
extra = ["天路编号-053__jianpucn-473423", "寂寞沙洲冷__qupu123-382747", "爱__qupu123-380781",
         "铁血丹心__qupu123-381085", "好好爱自己__qupu123-381554"]
for b in names + [x for x in extra if x not in names]:
    best = None
    for d in ("batch-out", "batch-out-dup", "batch-out-bad"):
        f = f"{d}/{b}.txt"
        if not os.path.exists(f):
            continue
        toks = [x for x in io.open(f, encoding="utf-8", errors="replace").read().split()
                if x and not x.startswith("%") and "=" not in x]
        nd = sum(1 for x in toks if x.rstrip(".'-") and x.rstrip(".'-")[-1] in DIG)
        if best is None or nd > best[2]:
            best = (d, len(toks), nd)
    if best:
        print(f"  {best[0]:<16} token {best[1]:>4}  音符 {best[2]:>4}   {b[:54]}")
    else:
        print(f"  {'哪里都没有':<16}                        {b[:54]}")
