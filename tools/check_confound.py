# -*- coding: utf-8 -*-
"""回答"反超原有语料意味着什么"前, 先排掉一个混淆: 吸收批与原语料的**站点构成**是否一致。

如果吸收批里 qupu123 占比明显更高, 那"数字占比反超"可能只是**来源不同**造成的,
不能归功于"新判据收得准"。
用法: py -3.13 tools/check_confound.py
"""
import glob
import os
import re
import statistics
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def site(n):
    m = re.search(r"__([a-z0-9]+)-\d+$", n)
    return m.group(1) if m else "?"


ADMIT = {l.strip() for l in open("train-work/purity2_admit.txt", encoding="utf-8") if l.strip()}
SIDS = {re.search(r"__([a-z0-9]+-\d+)$", x).group(1) for x in ADMIT if "__" in x}


def digits_ratio(f):
    t = open(f, encoding="utf-8", errors="replace").read().split()
    if not t:
        return None, None
    d = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    return d / len(t), len(t)


new, old = [], []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)[:-4]
    if b in ("progress", "skipped"):
        continue
    m = re.search(r"__([a-z0-9]+-\d+)$", b)
    r, n = digits_ratio(f)
    if r is None:
        continue
    (new if (m and m.group(1) in SIDS) else old).append((b, r, n, site(b)))

for tag, rows in (("吸收批", new), ("原有  ", old)):
    c = Counter(s for _b, _r, _n, s in rows)
    tot = len(rows)
    print(f"{tag} n={tot}  站点构成: " + "、".join(f"{k} {100.0*v/tot:.0f}%" for k, v in c.most_common()))

print("\n--- 按站点分别比数字占比(这样才是同口径比较)")
for s in ("qupu123", "jianpucn", "jianpujia"):
    a = [r for _b, r, _n, ss in new if ss == s]
    b = [r for _b, r, _n, ss in old if ss == s]
    if not a or not b:
        print(f"  {s}: 吸收批 {len(a)} 份 / 原有 {len(b)} 份 —— 样本不足, 不比")
        continue
    lo_a = 100.0 * sum(1 for v in a if v < 0.5) / len(a)
    lo_b = 100.0 * sum(1 for v in b if v < 0.5) / len(b)
    print(f"  {s}: 吸收批 n={len(a)} 中位 {statistics.median(a):.1%} (<50% 占 {lo_a:.1f}%)  |  "
          f"原有 n={len(b)} 中位 {statistics.median(b):.1%} (<50% 占 {lo_b:.1f}%)")
