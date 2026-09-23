# -*- coding: utf-8 -*-
"""量"裸行 usertag"通道还有没有在用 —— 这决定"先读 k=v"方案是否完备。
score.py read() L369: 既不是 k=v、也不是 % 行、也不是文件名行的, 一律当 usertag。
"""
import glob
import io
import os
import re
import sys
from collections import Counter

os.chdir(r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")

bare = Counter()
n_bare = 0
files_with_bare = []
kv = Counter()
for f in glob.glob("scores/*.txt"):
    if f.endswith("_expand.txt") or f.endswith("_buf.txt"):
        continue
    meta_done = False
    for line in io.open(f, encoding="utf-8", errors="replace"):
        s = line.rstrip("\n")
        ss = s.replace(" ", "")
        if ss.startswith("%--"):
            meta_done = True
            continue
        if meta_done:
            continue
        if not s.strip():
            continue
        if ss.startswith("%"):
            continue
        if "=" in s:
            kv[s.split("=", 1)[0].strip()] += 1
            continue
        if s.strip() == os.path.basename(f):
            continue
        # 到这里 = score.py L369 的"裸 usertag"分支
        bare[s.strip()] += 1
        n_bare += 1
        if len(files_with_bare) < 5:
            files_with_bare.append((os.path.basename(f), s.strip()))

print(f"裸行(无 =)出现 {n_bare} 次, 涉及 {len(bare)} 个不同值")
print("  值分布(前 10):", dict(bare.most_common(10)))
print("  例:", files_with_bare)
print(f"\n带 = 的字段出现次数(前 12): {dict(kv.most_common(12))}")
