# -*- coding: utf-8 -*-
"""列出全库中"以 1123555 开头"的歌(用户哼的是开头句), 并标出紧跟的音, 用于定曲。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A = "1123555"
rows = []
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        try:
            e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
        except Exception:
            continue
        pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
        s = "".join(x[0] for x, _ in pr)
        if s.startswith(A):
            b = os.path.basename(f)[:-4]
            octs = " ".join(x for x, _ in pr[:13])
            rows.append((b.split("__")[0], b, s[:18], octs))

print(f"以 {A} 开头的歌: {len(rows)} 首\n")
seen = set()
for name, b, head, octs in sorted(rows):
    key = name
    dup = "  (另有版本)" if key in seen else ""
    seen.add(key)
    print(f"  {name[:26]:<28} {head:<20} {octs}{dup}")
