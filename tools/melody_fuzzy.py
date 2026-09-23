# -*- coding: utf-8 -*-
"""模糊旋律检索: 允许少量错音(汉明距离), 找最接近的曲子。
用途: 用户凭耳朵报的音常有一两个错, 严格 LCS 会 0 命中, 这个能给出候选。
用法: py -3.13 tools/melody_fuzzy.py 312632126 [--max 2] [--top 12]
说明: 在"去掉八度/休止"的音高串上滑窗比较, 允许 max 个位置不同(不计移位)。
"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

q = sys.argv[1]
MAXM = int(sys.argv[sys.argv.index("--max") + 1]) if "--max" in sys.argv else 2
TOP = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 12
SKIP = "0x"

SOURCES = [
    ("我转写的", "batch-out/*.txt"),
    ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
]
print(f"查询 {q} ({len(q)} 音)   允许错 {MAXM} 个\n")
rows = []
for label, pat in SOURCES:
    for f in glob.glob(pat):
        b = os.path.basename(f)
        if b in ("progress.txt", "skipped.txt"):
            continue
        try:
            txt = open(f, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        e, raws = M.enc(txt)
        d = "".join(x[0] for x in e if x[0] not in SKIP)
        if len(d) < len(q):
            continue
        best, bi = 99, -1
        for i in range(len(d) - len(q) + 1):
            w = d[i:i + len(q)]
            m = sum(1 for a, c in zip(q, w) if a != c)
            if m < best:
                best, bi = m, i
                if best == 0:
                    break
        if best <= MAXM:
            rows.append((best, len(d), label, b[:-4], bi, d, raws))
rows.sort(key=lambda x: (x[0], x[1]))
print(f"命中(错 <= {MAXM}): {len(rows)}\n")
for best, n, label, name, bi, d, raws in rows[:TOP]:
    lo = max(0, bi - 6)
    print(f"  错{best}  {name[:46]:48s} 共{n:5d}音  [{label}]")
    print(f"        {d[lo:bi + len(q) + 10]}")
print("\n注: 只按音高+滑窗比对, 不做移调; 错 1-2 个的候选要人工确认。")
