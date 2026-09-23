# -*- coding: utf-8 -*-
"""两段旋律都要出现(按音高, 不看八度, **忽略休止符 0 和认不出的 x**)。
休止符一定要忽略: 谱里常写成 `11 0 76755`, 用户凭耳朵报的话不会报休止, 严格匹配会漏。
用法: py tools/melody_two.py 1117637 1176755 [--ctx 16]
"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

A = sys.argv[1]
B = sys.argv[2]
CTX = int(sys.argv[sys.argv.index("--ctx") + 1]) if "--ctx" in sys.argv else 16
SKIP = "0x"

SOURCES = [
    ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("我转写的", "batch-out/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
    ("GT手写", "train-work/gt/*.txt"),
]

print(f"两段都要有(忽略休止): A={A}  B={B}\n")
for label, pat in SOURCES:
    rows = []
    for f in glob.glob(pat):
        b = os.path.basename(f)
        if b in ("progress.txt", "skipped.txt"):
            continue
        try:
            txt = open(f, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        e, raws = M.enc(txt)
        d, idx = [], []          # d = 音高串(丢八度、丢休止), idx = 对应回 raws 的下标
        for k, (dig, _r) in enumerate(zip(e, raws)):
            if dig[0] in SKIP:
                continue
            d.append(dig[0])
            idx.append(k)
        d = "".join(d)
        if A not in d or B not in d or len(d) < 12:
            continue
        ia, ib = d.find(A), d.find(B)
        p0, p1 = idx[max(0, ia - CTX)], idx[min(len(idx) - 1, ia + len(A) + CTX)]
        rows.append((len(d), b[:-4], ia, ib, " ".join(raws[p0:p1 + 1]), ia, ib))
    rows.sort(key=lambda x: x[0])
    print(f"=== {label}  两段都有: {len(rows)} ===")
    for n, name, ia, ib, seg, _, _ in rows[:6]:
        print(f"  {name[:46]:48s} 共{n}音  A@{ia}  B@{ib}")
        print(f"      原文: {seg}")
    if not rows:
        print("   (无)")
    print()
