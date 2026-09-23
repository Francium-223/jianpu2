# -*- coding: utf-8 -*-
"""核对用户指出的原曲《让一切随风》(钟镇涛): 库里有没有、旋律是否对得上 33332123223216。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

Q = "33332123223216"
for nm in ("让一切随风", "钟镇涛", "一切随风"):
    hits = []
    for d in ("jianpu-db-out/scores", "batch-out", "batch-out-dup", "batch-out-bad"):
        hits += [f for f in glob.glob(d + "/*.txt") if nm in os.path.basename(f)]
    print(f"{nm}: {len(hits)} 份")
    for h in hits[:6]:
        print("    " + os.path.basename(h)[:60])

print()
fs = []
for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
    fs += [f for f in glob.glob(pat) if "让一切随风" in os.path.basename(f)]
for f in fs[:4]:
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    s = "".join(x[0] for x, _ in pr)
    mn, at = 99, -1
    for i in range(max(0, len(s) - len(Q) + 1)):
        m = sum(1 for a, b in zip(s[i:i + len(Q)], Q) if a != b)
        if m < mn:
            mn, at = m, i
    print(f"  {os.path.basename(f)[:52]}  音符 {len(s)}  与你片段最小错 {mn} @{at+1}")
    print("     开头 26 音: " + " ".join(s[:26]))
    print("     开头 26 音(带八度): " + " ".join(x for x, _ in pr[:26]))
