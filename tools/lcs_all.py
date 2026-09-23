# -*- coding: utf-8 -*-
"""用修好的解析器(认 c、剔除三连音标记、连音线合并)对**全部本地源**做最长公共子串扫描。"""
import glob, io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")

NOTE = re.compile(r"^[,']*[qsdhc]*[,']*([1-7])")
STRUCT = set("[](){}~|")
TUPLET = re.compile(r"^([0-9])\s*\[$")


def digits_from(path):
    try:
        lines = io.open(path, encoding="utf-8", errors="replace").read().splitlines()
    except Exception:
        return ""
    start = 0
    for i, l in enumerate(lines):
        if l.strip().lower().startswith("%--"):
            start = i + 1
            break
    out = []
    for l in lines[start:]:
        if l.startswith("%"):
            continue
        for t in l.split():
            if TUPLET.match(t) or (t and all(ch in STRUCT for ch in t)):
                continue                      # 三连音标记 / 结构符号
            m = NOTE.match(t)
            if m:
                out.append(m.group(1))
    return "".join(out)


def lcs(a, b):
    if not a or not b:
        return 0, ""
    prev = [0] * (len(b) + 1)
    best = (0, "")
    for i in range(1, len(a) + 1):
        cur = [0] * (len(b) + 1)
        ai = a[i - 1]
        for j in range(1, len(b) + 1):
            if ai == b[j - 1]:
                cur[j] = prev[j - 1] + 1
                if cur[j] > best[0]:
                    best = (cur[j], a[i - cur[j]:i])
        prev = cur
    return best


q = sys.argv[1] if len(sys.argv) > 1 else "67111137766654511"
print(f"查询 {q} ({len(q)} 音)\n")
SRC = [
    ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
    ("我转写的", "batch-out/*.txt"),
]
for label, pat in SRC:
    rows = []
    for f in glob.glob(pat):
        if os.path.basename(f) in ("progress.txt", "skipped.txt"):
            continue
        d = digits_from(f)
        if len(d) < 8:
            continue
        L, seg = lcs(q, d)
        if L >= 7:
            rows.append((L, os.path.basename(f)[:-4], len(d), seg))
    rows.sort(key=lambda x: (-x[0], x[2]))
    print(f"=== {label} ({pat})  命中 {len(rows)} ===")
    for L, name, n, seg in rows[:6]:
        print(f"   {L:2d}/{len(q)}  {name[:46]:48s} 共{n:5d}音  段:{seg}")
    if not rows:
        print("   (最长公共子串 < 7 音)")
    print()
