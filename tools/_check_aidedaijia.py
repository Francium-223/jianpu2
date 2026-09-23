# -*- coding: utf-8 -*-
"""核对候选歌《爱的代价》: 开头原始 token(带八度) + 两段查询的实际位置与连续性。"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A, B = "1123555", "555532"
NAMES = sys.argv[1:] or ["爱的代价", "爱情", "大约在冬季", "老鼠爱大米"]

for name in NAMES:
    fs = sorted(set(glob.glob(f"batch-out/*{name}__*.txt") + glob.glob(f"batch-out-dup/*{name}__*.txt")))
    if not fs:
        print(f"\n=== {name}: 库里没有")
        continue
    for f in fs[:2]:
        e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
        pairs = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
        s = "".join(x[0] for x, _ in pairs)
        ia, ib = s.find(A), s.find(B)
        print(f"\n=== {os.path.basename(f)[:-4][:52]}  音符 {len(s)}")
        print("   开头 24 音(带八度): " + " ".join(f"{x}" for x, _ in pairs[:24]))
        print("   开头 24 音(简谱):   " + " ".join(r for _, r in pairs[:24]))
        print(f"   第1段 {A} @ {ia+1 if ia>=0 else '无'}   第2段 {B} @ {ib+1 if ib>=0 else '无'}"
              f"   两段间距 {ib-ia if ia >= 0 and ib >= 0 else '-'}")
        if ia >= 0:
            print("   拼接处: " + s[max(0, ia - 3):ia + len(A) + len(B) + 3])
