# -*- coding: utf-8 -*-
"""抽检: raw batch-out 里有没有非音符 token(会被 to_jianpu_db.clean_tokens 丢掉)。"""
import collections
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

PAT = re.compile(r"[qsdh]*[,']*[1-7x0]\.*|[-0]")
bad = collections.Counter()
nfile = 0
for f in glob.glob("batch-out/*.txt"):
    ks = set()
    for t in open(f, encoding="utf-8", errors="replace").read().split():
        if not PAT.fullmatch(t):
            ks.add(t)
    for k in ks:
        bad[k] += 1
    if ks:
        nfile += 1
tot = len(glob.glob("batch-out/*.txt"))
print(f"有杂 token 的文件 {nfile}/{tot}")
for k, v in bad.most_common(10):
    print(f"   {k!r:14} 出现在 {v} 个文件")
