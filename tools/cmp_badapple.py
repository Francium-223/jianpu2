# -*- coding: utf-8 -*-
"""对比查询串与 th04_07(Bad Apple!!) 的数字串。"""
import io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu-db")

NOTE = re.compile(r"^[,']*[qsdhc]*[,']*([1-7])")


def digs(p):
    lines = io.open(p, encoding="utf-8", errors="replace").read().splitlines()
    start = 0
    for i, l in enumerate(lines):
        if l.strip().lower().startswith("%--"):
            start = i + 1
            break
    out = []
    for l in lines[start:]:
        if l.startswith("%") or not l:
            continue
        for t in l.split():
            m = NOTE.match(t)
            if m:
                out.append(m.group(1))
    return "".join(out)


q = "67111137766654511"
for f in ["scores/th04_07.txt", "scores/th04_07_expand.txt"]:
    if not os.path.exists(f):
        print(f, "不存在")
        continue
    d = digs(f)
    print(f"{f}: {len(d)} 音")
    print("  开头 50:", d[:50])
    print("  含完整查询串:", q in d)
    best = (0, "")
    for i in range(len(q)):
        for j in range(i + 1, len(q) + 1):
            if q[i:j] in d and j - i > best[0]:
                best = (j - i, q[i:j])
    print(f"  最长公共子串: {best[0]} 音  {best[1]}")
