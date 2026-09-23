# -*- coding: utf-8 -*-
"""核一件事: 用户说这段是郑智化《水手》, 检索器说是《爱上草原的小河》——到底谁对。
做法: 把片段在各候选谱里滑窗比, 打出最小错音数与命中位置, 并印出谱里的实际片段。
用法: py -3.13 _check_shuishou.py
"""
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


print("=== 库里所有含'水手'的谱, 看这个片段在不在里面")
hits = []
for f in glob.glob("batch-out/*.txt") + glob.glob("batch-out-dup/*.txt"):
    b = os.path.basename(f)[:-4]
    p = pitch(f)
    if len(p) < len(Q):
        continue
    arr = np.frombuffer(p.encode(), dtype=np.uint8)
    w = np.lib.stride_tricks.sliding_window_view(arr, len(qa))
    mism = (w != qa).sum(axis=1)
    i = int(mism.argmin())
    m = int(mism[i])
    near = np.frombuffer(p.encode(), dtype=np.uint8)
    # 与片段的"最佳 13 音窗口"错几个
    if "水手" in b or "郑智化" in b:
        hits.append((m, b, i, p[max(0, i - 3):i + len(Q) + 3], len(p)))
    if m == 0:
        hits.append((0, b, i, p[max(0, i - 3):i + len(Q) + 3], len(p)))

hits.sort()
print(f"  「水手」相关谱 {sum(1 for h in hits if '水手' in h[1] or '郑智化' in h[1])} 个; 全库完全一致 {sum(1 for h in hits if h[0]==0)} 个")
for m, b, i, win, n in hits[:14]:
    tag = "水手" if ("水手" in b or "郑智化" in b) else "其它"
    print(f"  错{m:2d}  [{tag}] {b[:44]:<46} 音符{n:5d}  第{i+1:4d}音起: {win}")

print("\n=== 单独把所有「水手」谱列出来(错音数不限)")
for f in glob.glob("batch-out/*.txt") + glob.glob("batch-out-dup/*.txt"):
    b = os.path.basename(f)[:-4]
    if "水手" not in b and "郑智化" not in b:
        continue
    p = pitch(f)
    arr = np.frombuffer(p.encode(), dtype=np.uint8)
    best = 99
    pos = -1
    if len(arr) >= len(qa):
        w = np.lib.stride_tricks.sliding_window_view(arr, len(qa))
        mism = (w != qa).sum(axis=1)
        pos = int(mism.argmin())
        best = int(mism[pos])
    print(f"  错{best:2d}  {b[:52]:<54} 音符{len(arr):5d}  "
          + (f"第{pos+1}音起: {p[max(0,pos-3):pos+len(Q)+3]}" if pos >= 0 else "(太短)"))
