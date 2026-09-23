# -*- coding: utf-8 -*-
"""对照《再回首》《红蜻蜓》的开头, 定 3333 2123 223216 是哪首。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A, B = "33332123", "223216"
for nm in ("再回首", "红蜻蜓", "朋友别哭"):
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
    ia, ib = s.find(A), s.find(B)
    print(f"\n=== {os.path.basename(f)[:-4][:56]}  音符 {len(s)}")
    print(f"    开头 30 音: " + " ".join(s[:30]))
    print(f"    开头 30 音(带八度): " + " ".join(x for x, _ in pr[:30]))
    print(f"    A {A} @{ia+1 if ia>=0 else '无'}   B {B} @{ib+1 if ib>=0 else '无'}   间距 {ib-ia if ia>=0 and ib>=0 else '-'}")
    if ia >= 0:
        print(f"    命中处: " + " ".join(s[max(0, ia-4):ia+len(A)+len(B)+4]))
