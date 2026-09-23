# -*- coding: utf-8 -*-
"""公平基线: "开头起点" vs "串内任意起点" 出现 >=4 同音的概率。
若开头显著更高 -> 版面顶部装饰被读成音符的系统性伪影。
并打印最极端几例, 供人工看图确认。
"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

SKIP = "0x"


def pitch(f):
    e, _ = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    return "".join(x[0] for x in e if x[0] not in SKIP)


def runlen(s, i):
    k = 1
    while i + k < len(s) and s[i + k] == s[i]:
        k += 1
    return k


files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
H = M_ = tot = 0
head_hits = mid_hits = 0
head_pos = mid_pos = 0
for f in files:
    s = pitch(f)
    if len(s) < 13:
        continue
    tot += 1
    if runlen(s, 0) >= 4:
        head_hits += 1
    head_pos += 1
    for i in range(4, len(s)):
        mid_pos += 1
        if runlen(s, i) >= 4:
            mid_hits += 1
print(f"谱 {tot} 份")
print(f"开头起点 >=4 同音: {head_hits} / {head_pos} = {head_hits/head_pos*100:.2f}%")
print(f"串内起点 >=4 同音: {mid_hits} / {mid_pos} = {mid_hits/mid_pos*100:.2f}%")
print(f"**开头是串内的 {head_hits/head_pos/(mid_hits/mid_pos):.1f} 倍**")
