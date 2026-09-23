# -*- coding: utf-8 -*-
"""看某段旋律在若干首歌里的**上下文**(命中处前后各 14 个音), 用于人工分辨是哪首。

用法: py -3.13 tools/melody_context.py 52176552 赞家园 情人恰恰
"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from melody_all import digits_from_text  # 与检索工具同一套数字提取, 不另写 ✗

QUERY = sys.argv[1]
NAMES = sys.argv[2:]
PAD = 14

for nm in NAMES:
    hit = None
    for f in glob.glob("batch-out/*.txt") + glob.glob("jianpu-db-out/scores/*.txt"):
        if nm in os.path.basename(f):
            hit = f
            break
    if not hit:
        print(f"--- {nm}: 找不到文件")
        continue
    d = digits_from_text(io.open(hit, encoding="utf-8", errors="replace").read())
    i = d.find(QUERY)
    if i < 0:
        print(f"--- {nm}: 数字串里没有 {QUERY}")
        continue
    a, b = max(0, i - PAD), min(len(d), i + len(QUERY) + PAD)
    print(f"--- {nm}   共 {len(d)} 音   命中在第 {i+1} 音")
    print(f"    …{d[a:i]}[{d[i:i+len(QUERY)]}]{d[i+len(QUERY):b]}…")
