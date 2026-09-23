# -*- coding: utf-8 -*-
"""QA: 检查 jianpu-db scores 的格式与内容(拍号行/标题/%END/音符数异常)。"""
import glob, os, re, sys, collections
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

fs = glob.glob("jianpu-db-out/scores/*.txt")
print(f"scores: {len(fs)} 个")
bad_end = bad_meter = no_title = empty = 0
meters = collections.Counter()
note_counts = []
for f in fs:
    t = open(f, encoding="utf-8").read()
    lines = [l.strip() for l in t.splitlines()]
    if not any(l.upper().startswith("%END") for l in lines):
        bad_end += 1
    if not any(l.startswith("title=") for l in lines):
        no_title += 1
    try:
        i = next(i for i, l in enumerate(lines) if l == "%--")
    except StopIteration:
        bad_meter += 1
        continue
    meter = lines[i + 1] if i + 1 < len(lines) else ""
    if not re.match(r"^\d+/\d+$", meter):
        bad_meter += 1
    else:
        meters[meter] += 1
    body = [l for l in lines[i + 2:] if l and not l.startswith("%") and not l.startswith("subtitle=")]
    n = len(" ".join(body).split())
    note_counts.append(n)
    if n == 0:
        empty += 1

print(f"  缺 %END: {bad_end}")
print(f"  缺 title=: {no_title}")
print(f"  拍号行异常: {bad_meter}")
print(f"  正文为空: {empty}")
print(f"  拍号分布: {dict(meters.most_common(8))}")
if note_counts:
    note_counts.sort()
    print(f"  音符数: 最小 {note_counts[0]}, 中位 {note_counts[len(note_counts)//2]}, 最大 {note_counts[-1]}")
print("\n样例(第一个):")
f0 = sorted(fs)[0]
print("  " + os.path.basename(f0))
for l in open(f0, encoding="utf-8").read().splitlines()[:12]:
    print("    " + l[:88])
