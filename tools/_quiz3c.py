# -*- coding: utf-8 -*-
"""打印几个"1 错候选"的原始音符, 看谁真的存在"上句 366563 → 下句上行一步"的模进结构。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

NAMES = ["明月千里寄相思", "三生三世", "爱上草原爱上你", "阿拉里哟", "乘风乘月乘忧去", "一剪梅"]
for nm in NAMES:
    fs = []
    for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
        fs += [f for f in glob.glob(pat) if nm in os.path.basename(f)]
    if not fs:
        print(f"\n=== {nm}: 库里没有")
        continue
    f = fs[0]
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    s = "".join(x[0] for x, _ in pr)
    i = s.find("366563")
    print(f"\n=== {os.path.basename(f)[:-4][:52]}  音符 {len(s)}  366563 @{i+1 if i>=0 else '无'}")
    lo = max(0, (i if i >= 0 else 0) - 6)
    print("   简谱: " + " ".join(r for _, r in pr[lo:lo + 34]))
    print("   音级: " + " ".join(s[lo:lo + 34]))
