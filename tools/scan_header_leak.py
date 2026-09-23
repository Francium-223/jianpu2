# -*- coding: utf-8 -*-
"""量化"调号行漏进音符"有多普遍。

特征: 转写结果的**开头**出现成片的 '-' 和 'x' —— 那是被读成音符的调号行
(如 `1=D 4/4 ♩=72 亲切温馨地` -> `q1 qx - - - - 7 7 2 4 4 x x`)。
真正的音乐开头通常是数字, 或 0(休止), 不会连着 3 个以上 '-' 还夹 x。
"""
import glob
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
print(f"转写结果 {len(files)} 个")

N = 14
hit = []
for f in files:
    toks = io.open(f, encoding="utf-8").read().split()
    head = toks[:N]
    # 只数"独立符号" token
    nd = sum(1 for t in head if t == "-")
    nx = sum(1 for t in head if t == "x")
    if nd >= 3 and nx >= 1:
        hit.append((os.path.basename(f)[:-4], " ".join(head)))

print(f"开头 {N} 个 token 里 有 >=3 个 '-' 且 >=1 个 'x' 的: {len(hit)} 个"
      f"  ({100*len(hit)/max(len(files),1):.1f}%)")
print()
for name, head in hit[:12]:
    print(f"  {name[:52]}")
    print(f"      {head[:100]}")
