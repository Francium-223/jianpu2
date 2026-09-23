# -*- coding: utf-8 -*-
"""全库统计: 3565321232176 这段到底有多少首歌含有(0 错位)。以及各长度下的唯一性。"""
import glob
import io
import os
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import melody_oct as M

SKIP = "0x"
FULL = "3565321232176"
VARIANTS = [
    "3565321232176",   # 用户给的 13 音
    "1233565321232176",
    "3335653212321766711",
    "565321232176",
    "5653212321766",
    "165321232176",
    "56532123217667",
]

cache = {}
FS = sorted(glob.glob("jianpu-db-out/scores/*.txt"))
print(f"扫描 {len(FS)} 个谱文件")
for f in FS:
    txt = io.open(f, encoding="utf-8", errors="replace").read()
    e, _ = M.enc(txt)
    p = "".join(x[0] for x in e if x[0] not in SKIP)
    if len(p) < 8:
        continue
    name = os.path.basename(f)[:-4]
    song = name.split("__")[0]
    cache.setdefault(song, []).append((name, p))

print(f"全库歌曲 {len(cache)}  谱 {sum(len(v) for v in cache.values())}\n")
for q in VARIANTS:
    hits = []
    for song, arr in cache.items():
        n = sum(p.count(q) for _, p in arr)
        if n:
            hits.append((song, n))
    tot = sum(n for _, n in hits)
    print(f"  {q:<22} ({len(q):2d}音)  歌 {len(hits):3d} 首  出现 {tot:3d} 次")
    if len(hits) <= 14:
        for s, n in sorted(hits, key=lambda x: -x[1])[:14]:
            print(f"        {s[:52]:<54} ×{n}")
    print()

# 各长度下的唯一性曲线 (取 水手 上该段沿伸)
print("唯一性曲线(以水手 268596 第 221 音为锚, 向前后各取 n 音):")
sa = [v for k, v in cache.items() if k.startswith("水手")]
p0 = next(p for _, p in sa[0] if "3565321232176" in p)
i0 = p0.find("3565321232176")
for n in (9, 11, 13, 15, 17, 19, 21, 25):
    a = max(0, i0 - (n - 13) // 2)
    q = p0[a:a + n]
    hits = [s for s, arr in cache.items() if any(q in p for _, p in arr)]
    print(f"  n={n:2d}  {q:<26} 命中歌 {len(hits):3d} 首  {hits[:4]}")
