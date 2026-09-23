# -*- coding: utf-8 -*-
"""判定: 谁的谱里 A(33332123) 之后**紧跟** B(223216)（允许每段 1 个错音），且是全曲 0 错的那批候选。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A, B = "33332123", "223216"
LINE = A + B
SKIP = "0x"


def load(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in SKIP]
    return "".join(x[0] for x, _ in pr), " ".join(x for x, _ in pr), " ".join(r for _, r in pr)


best = {}          # 曲名 -> (A后紧跟B的最小错音, 文件名, 位置, 窗口)
for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        try:
            s, enc, raw = load(f)
        except Exception:
            continue
        if len(s) < len(LINE):
            continue
        b = os.path.basename(f)[:-4]
        song = b.split("__")[0]
        for i in range(len(s) - len(LINE) + 1):
            win = s[i:i + len(LINE)]
            # 逐段允许 1 错: A 段与 B 段各自比
            ea = sum(1 for x, y in zip(win[:len(A)], A) if x != y)
            eb = sum(1 for x, y in zip(win[len(A):], B) if x != y)
            tot = ea + eb
            if tot <= 2:
                prev = best.get(song)
                if prev is None or tot < prev[0]:
                    best[song] = (tot, b, i + 1, win, ea, eb, raw)
print(f"A+B 连续、总错 <=2 的曲目 {len(best)} 个\n")
for song, (tot, b, pos, win, ea, eb, raw) in sorted(best.items(), key=lambda x: x[1][0])[:12]:
    print(f"  错{tot} (A段{ea}+B段{eb})  {song[:24]:<26} @{pos:<4} {b[:40]}")
    print(f"       谱里: {win}")
