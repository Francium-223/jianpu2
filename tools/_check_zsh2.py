# -*- coding: utf-8 -*-
"""核对工具实际命中的两个文件: 再回首__qupu123-361353 与 红蜻蜓__qupu123-344590。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A, B = "33332123", "223216"
TARGETS = ["再回首__qupu123-361353", "红蜻蜓__qupu123-344590"]
for base in TARGETS:
    hit = None
    for pat in ("jianpu-db-out/scores/", "batch-out/", "batch-out-dup/"):
        if os.path.exists(pat + base + ".txt"):
            hit = pat + base + ".txt"
            break
    if not hit:
        print(f"\n=== {base}: 找不到文件")
        continue
    e, raws = M.enc(io.open(hit, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    s = "".join(x[0] for x, _ in pr)
    ia, ib = s.find(A), s.find(B)
    print(f"\n=== {base}   音符 {len(s)}")
    print(f"    开头 28 音:      " + " ".join(s[:28]))
    print(f"    开头 28 音(八度): " + " ".join(x for x, _ in pr[:28]))
    print(f"    A({A}) @{ia+1 if ia>=0 else '无'}   B({B}) @{ib+1 if ib>=0 else '无'}")
    if ia >= 0:
        print(f"    A 处上下文: " + " ".join(s[max(0, ia-6):ia+len(A)+len(B)+6]))
        print(f"    A 处 token : " + " ".join(raws[max(0, ia-6):ia+len(A)+len(B)+6]))
