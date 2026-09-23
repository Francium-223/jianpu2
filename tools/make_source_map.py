# -*- coding: utf-8 -*-
"""生成"标题 -> 来源站"映射表(旁路文件, 不动 jianpu-db 的 score 格式)。

为什么用旁路: score 格式里的 tag= 会被下游 parse_scores.py 重写成空
(实测展开文件里 tag= 是空的), 所以来源写进 score 无效。

输出 train-work/source_map.tsv:  标题<TAB>来源站<TAB>目录名
用法: py tools/make_source_map.py
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT
from to_jianpu_db import source_of, title_of

# 只列当前语料里的(有转写结果的)
have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
have -= {"progress.txt", "skipped.txt"}
rows = []
for d in sorted(x for x in glob.glob("images-prep/*/*") if os.path.isdir(x)):
    name = os.path.basename(d.rstrip("/\\"))
    if BT.safe_name(name) not in have:
        continue
    rows.append((title_of(name), source_of(name), name))

os.makedirs("train-work", exist_ok=True)
with open("train-work/source_map.tsv", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, delimiter="\t")
    w.writerow(["title", "source", "dir"])
    w.writerows(rows)
import collections
c = collections.Counter(s for _, s, _ in rows)
print(f"映射表 {len(rows)} 条 -> train-work/source_map.tsv")
print("来源分布:", dict(c.most_common()))
