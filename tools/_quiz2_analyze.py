# -*- coding: utf-8 -*-
"""对 13 首"0 错并列"的候选逐个分析: 两段各自位置、间距、八度差, 判断哪首的**开头**对得上。"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A, B = "1123555", "555532"
QOFF = [0] * len(A)


def load(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    return "".join(x[0] for x, _ in pr), "".join(x for x, _ in pr), " ".join(r for _, r in pr[:22])


# 全部含这两段的歌
hits = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        try:
            s, enc, head = load(f)
        except Exception:
            continue
        if len(s) < 12:
            continue
        if A in s and B in s:
            b = os.path.basename(f)[:-4]
            hits.setdefault(b.split("__")[0], []).append((b, s, enc, head))

print(f"两段都精确存在的歌: {len(hits)} 首\n")
for name, lst in sorted(hits.items(), key=lambda x: len(x[0])):
    for b, s, enc, head in lst[:1]:
        ia, ib = s.find(A), s.find(B)
        # 八度差: 把谱里那段 vs 用户原样(全 +0)
        def diff(i, q):
            seg = enc[i * 3:i * 3 + len(q) * 3]
            return sum(1 for j in range(len(q)) if seg[j * 3:j * 3 + 3] != f"{q[j]}+0")
        print(f"  {name[:20]:<22} 音符{len(s):>4}  A@{ia+1:<4}(八度差{diff(ia, A)}) "
              f"B@{ib+1:<4}(八度差{diff(ib, B)}) 间距{ib-ia:<5} {'★开头' if ia <= 2 else ''}")
        if ia <= 2 or ib - ia <= len(A) + 1:
            print(f"        开头: {head}")
