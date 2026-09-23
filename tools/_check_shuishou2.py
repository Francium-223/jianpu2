# -*- coding: utf-8 -*-
"""核:《水手》(刚抓的三份)里有没有 35653 21232176 这段, 以及错几个音。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import melody_oct as M

Q = "3565321232176"
SKIP = "0x"
qa = np.frombuffer(Q.encode(), dtype=np.uint8)


def pitch(path):
    e, _ = M.enc(io.open(path, encoding="utf-8", errors="replace").read())
    return "".join(x[0] for x in e if x[0] not in SKIP)


print(f"查询片段 {Q} ({len(Q)} 音)")
for f in sorted(glob.glob("batch-out/水手*.txt")):
    p = pitch(f)
    arr = np.frombuffer(p.encode(), dtype=np.uint8)
    if len(arr) < len(qa):
        print(f"  {os.path.basename(f)[:44]:<46} 太短({len(arr)} 音)")
        continue
    w = np.lib.stride_tricks.sliding_window_view(arr, len(qa))
    mism = (w != qa).sum(axis=1)
    order = np.argsort(mism)[:3]
    print(f"\n  {os.path.basename(f)[:48]}  音符 {len(arr)}")
    for i in order:
        i = int(i)
        print(f"     错{int(mism[i]):2d}  第{i+1:4d}音起: {p[max(0,i-4):i+len(Q)+4]}")

# 对照: 爱上草原的小河那段
for f in sorted(glob.glob("batch-out/爱上草原的小河*.txt"))[:1]:
    p = pitch(f)
    i = p.find(Q)
    print(f"\n  对照《爱上草原的小河》: 第{i+1}音起 {p[max(0,i-4):i+len(Q)+4]}")
