# -*- coding: utf-8 -*-
"""看清 3565321232176 这一段在 爱上草原 与 水手 里的原始 token(含八度/时值)。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

Q = "3565321232176"


def show(path):
    txt = io.open(path, encoding="utf-8", errors="replace").read()
    e, raws = M.enc(txt)
    a = "".join(x[0] for x in e)
    i = a.find(Q)
    if i < 0:
        print(f"  {os.path.basename(path)[:44]}  音级口径未命中")
        return
    lo, hi = max(0, i - 10), min(len(raws), i + len(Q) + 10)
    print(f"\n  {os.path.basename(path)[:50]}   第 {i+1} 音起")
    print("    raw : " + " ".join(f"{t:>5}" for t in raws[lo:hi]))
    print("    enc : " + " ".join(f"{x:>5}" for x in e[lo:hi]))
    print("    八度非零的音: " + (", ".join(
        f"第{lo+j+1}音 {raws[lo+j]}={e[lo+j]}" for j in range(hi - lo) if not e[lo + j].endswith("+0")
    ) or "无"))


for pat in ("jianpu-db-out/scores/爱上草原的小河*.txt", "batch-out/水手*.txt"):
    for f in sorted(glob.glob(pat)):
        show(f)
