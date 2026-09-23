# -*- coding: utf-8 -*-
"""用 kind_v2 的谱表组数分类, 交叉验证音符数, 定阈值。"""
import collections, csv, glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

rows = list(csv.DictReader(open("train-work/kind_v2.tsv", encoding="utf-8"), delimiter="\t"))
for r in rows:
    for k in ("staff_groups", "groups", "long_rows"):
        r[k] = int(r[k])

def notes_of(d):
    nm = BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        m = re.search(r"([A-Za-z]+\d*-\d+)$", d)
        g = glob.glob(f"batch-out/*{glob.escape(m.group(1))}.txt") if m else []
        if not g:
            return None
        f = g[0]
    t = open(f, encoding="utf-8").read().split()
    return sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")

print("谱表组数分布 + 平均音符数:")
c = collections.Counter(); c2 = collections.defaultdict(list)
for r in rows:
    b = min(r["staff_groups"], 12)
    c[b] += 1
    n = notes_of(r["dir"])
    if n is not None:
        c2[b].append(n)
for b in sorted(c):
    avg = round(sum(c2[b]) / len(c2[b]), 1) if c2[b] else "-"
    print(f"  组数 {b:2d}{'+' if b==12 else ' '}: {c[b]:5d} 个, 已转 {len(c2[b]):4d}, 平均音符 {avg}")

print("\n各组已转样本里 '有音符(>=10)' 的比例:")
for b in sorted(c):
    ns = c2[b]
    if not ns:
        continue
    print(f"  组数 {b:2d}: {sum(1 for x in ns if x>=10)}/{len(ns)} 有音符")
