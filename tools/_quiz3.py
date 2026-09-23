# -*- coding: utf-8 -*-
"""定位 366563 / 377673: (a) 以 366563 开头的歌; (b) 两段都含且相邻的歌; (c) 全库 0 错命中情况。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A, B = "366563", "377673"
SKIP = "0x"


def load(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in SKIP]
    return "".join(x[0] for x, _ in pr), " ".join(x for x, _ in pr[:16]), " ".join(r for _, r in pr[:16])


corp = {}
for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        try:
            s, enc, raw = load(f)
        except Exception:
            continue
        if len(s) >= 12:
            corp[os.path.basename(f)[:-4]] = (s, enc, raw)

print(f"索引 {len(corp)} 份谱\n")

print("(a) 以 366563 开头的:")
n = 0
for b, (s, enc, raw) in sorted(corp.items()):
    if s.startswith(A):
        n += 1
        print(f"   {b[:44]:<46} {raw}")
print(f"   共 {n} 份\n")

print("(b) 两段都精确含且相邻(间距<=6)的:")
for b, (s, enc, raw) in sorted(corp.items()):
    ia, ib = s.find(A), s.find(B)
    if ia >= 0 and ib >= 0 and 0 < ib - ia <= len(A) + 2:
        print(f"   {b[:44]:<46} A@{ia+1} B@{ib+1} 间距{ib-ia}  {raw}")
print()

print("(c) 含 366563 且含 377673(不限位置)的前 12 个曲名:")
cnt = 0
for b, (s, enc, raw) in sorted(corp.items()):
    if A in s and B in s:
        cnt += 1
        if cnt <= 12:
            print(f"   {b[:44]:<46} A@{s.find(A)+1} B@{s.find(B)+1}")
print(f"   共 {cnt} 份")
