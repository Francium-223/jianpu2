# -*- coding: utf-8 -*-
"""核对《爱情转移》命中处: 把你的 token 串与谱面逐音对照(含时值与八度)。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

Q = "1177676565323565"          # 你给的音高(去掉 '1 的八度记号后)
for f in glob.glob("batch-out/*爱情转移*陈奕迅*.txt") + glob.glob("batch-out*/爱情转移*.txt"):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    s = "".join(x[0] for x, _ in pr)
    i = s.find(Q[1:])           # 去掉首音后应 15 音全中
    if i < 0:
        continue
    lo = max(0, i - 4)
    print(f"=== {os.path.basename(f)[:-4][:60]}")
    print(f"    命中: 第 {i+1} 音起 (你给的串去掉首音后)")
    print("    谱面音级: " + " ".join(s[lo:lo + len(Q) + 6]))
    print("    谱面 token: " + " ".join(raws[lo:lo + len(Q) + 6]))
    print("    你的音高  : " + " ".join(Q))
    print("    你的 token: 1q '1q 7q 7q 6q 7q 6c 5q 6q 5q 3q 2q 3q 5q 6q 5q")
    break
