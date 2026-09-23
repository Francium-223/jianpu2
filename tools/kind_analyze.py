# -*- coding: utf-8 -*-
"""用 long_rows 分类, 并和已有转写结果(音符数)交叉验证, 定阈值。"""
import collections, csv, glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

rows = list(csv.DictReader(open("train-work/kind_fast.tsv", encoding="utf-8"), delimiter="\t"))
for r in rows:
    r["long_rows"] = int(r["long_rows"])

def notes_of(d):
    """该目录对应的 batch-out txt 的音符数(没有则 None)。"""
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

print("long_rows 分布 + 各组平均音符数:")
c = collections.Counter()
c2 = collections.defaultdict(list)
for r in rows:
    b = min(r["long_rows"] // 10 * 10, 120)
    c[b] += 1
    n = notes_of(r["dir"])
    if n is not None:
        c2[b].append(n)
for b in sorted(c):
    avg = round(sum(c2[b]) / len(c2[b]), 1) if c2[b] else "-"
    print(f"  lr {b:3d}-{b+10:<3d}: {c[b]:5d} 个, 平均音符 {avg}")

print("\n各阈值下被判为'非纯'的数量:")
for th in (5, 10, 15, 20, 25, 30, 40):
    nb = [r for r in rows if r["long_rows"] >= th]
    ns = [notes_of(r["dir"]) for r in nb]
    ns = [x for x in ns if x is not None]
    print(f"  lr>={th:3d}: {len(nb):4d} 个 (已转 {len(ns)}, 其中有音符的 {sum(1 for x in ns if x>=10)})")
