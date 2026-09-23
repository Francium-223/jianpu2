# -*- coding: utf-8 -*-
"""抽检: 语料里"名字像双声部/改编"的谱（钢琴/双手/四手/伴奏/弹唱/吉他/五线）。

为什么要单独列出来: 纯度门挡的是**五线谱/六线谱/混排**, 而"钢琴简谱"是**两行简谱**——
它确实不含五线谱(所以过门), 但它是**双声部**, 主旋律和伴奏混在一条 token 序列里,
拿去做旋律检索会往里掺和弦音。语料里本来就有这类(实测 371 份), 补转 PNG 又进来一批。
这里只**列清单**(不改语料、不删东西), 要不要移出/单独标注由你定:
    py -3.13 tools/list_arrangement_like.py            # 生成清单
移出(如果你想): 把清单里的名字喂给 tools/transcribe_source.py 的反向逻辑, 或直接
   move 到 batch-out-suspect/ (保留不删)。

用法: py -3.13 tools/list_arrangement_like.py
产物: train-work/arrangement_like.tsv (目录名 \t 判据词 \t 当前所在结果目录)
"""
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

WORDS = ["钢琴", "双手", "四手", "伴奏", "弹唱", "吉他", "五线", "简线", "总谱", "和弦"]
RD = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]

rows = []
for rd in RD:
    for f in glob.glob(f"{rd}/*.txt"):
        b = os.path.basename(f)[:-4]
        hit = [w for w in WORDS if w in b]
        if hit:
            rows.append((b, "、".join(hit), rd))

with open("train-work/arrangement_like.tsv", "w", encoding="utf-8") as f:
    f.write("曲名\t判据词\t所在结果目录\n")
    for r in rows:
        f.write("\t".join(r) + "\n")

import collections
c = collections.Counter(r[2] for r in rows)
print(f"名字像双声部/改编的谱: {len(rows)} 份")
print("  分布: " + "、".join(f"{k} {v}" for k, v in c.most_common()))
w = collections.Counter(x for r in rows for x in r[1].split("、"))
print("  判据词: " + "、".join(f"{k} {v}" for k, v in w.most_common(8)))
print("-> train-work/arrangement_like.tsv (只列清单, 没动语料)")
