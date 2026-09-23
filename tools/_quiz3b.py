# -*- coding: utf-8 -*-
"""分别列出全库"精确含 366563"与"精确含 377673"的歌, 找熟面孔。"""
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


c1, c2 = [], []
for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        try:
            s = pitch(f)
        except Exception:
            continue
        if len(s) < 6:
            continue
        b = os.path.basename(f)[:-4]
        if "366563" in s:
            c1.append((b, s.find("366563") + 1))
        if "377673" in s:
            c2.append((b, s.find("377673") + 1))
print(f"含 366563 的谱 {len(c1)} 份;  含 377673 的谱 {len(c2)} 份\n")
print("=== 含 366563 ===")
for b, i in c1[:40]:
    print(f"   @{i:<5} {b[:60]}")
print("\n=== 含 377673 ===")
for b, i in c2[:40]:
    print(f"   @{i:<5} {b[:60]}")
