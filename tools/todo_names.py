# -*- coding: utf-8 -*-
"""把 scores 里带 `todo=refine the filename` 的曲名**映射回源目录名** -> train-work/todo_names.txt。

为什么需要: 清名表(title_clean.tsv)是按**目录名**索引的, 而 todo 标记在 scores 里;
scores 里的 `source=<站>-<id>` 就是目录名的后缀, 用它反查即可。

用法: py -3.13 tools/todo_names.py
"""
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

dirs = [os.path.basename(d) for d in glob.glob("images-prep/*/*") if os.path.isdir(d)]
by_src = {}
for d in dirs:
    m = re.match(r"^.*__([a-z0-9]+-\d+)$", d)
    if m:
        by_src[m.group(1)] = d

rows, unmapped = [], []
for f in glob.glob("jianpu-db-out/scores/*.txt"):
    t = open(f, encoding="utf-8", errors="replace").read(2000)
    if "todo=refine the filename" not in t:
        continue
    m = re.search(r"^source=(\S+)", t, re.M)
    s = m.group(1) if m else ""
    d = by_src.get(s)
    if d:
        rows.append(d)
    else:
        unmapped.append((os.path.basename(f)[:-4], s))

with open("train-work/todo_names.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + ("\n" if rows else ""))
print(f"映射到目录 {len(rows)} 条 -> train-work/todo_names.txt")
if unmapped:
    print(f"映射不到的 {len(unmapped)} 条(可能是手工抓的谱, 没有站点 id):")
    for n, s in unmapped[:10]:
        print(f"    {n[:44]}  source={s or '(无)'}")
