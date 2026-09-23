# -*- coding: utf-8 -*-
"""量一下这轮"按歌手扩库"的**净新增率**: 转进来的谱里, 有多少是语料里**本来没有的曲名**?

为什么值得量: 扩库最容易自欺的地方就是"转了很多, 但都是已有歌的另一个版本"。
判据: 目录名的"曲名头"(去站点后缀、去括号注释)与语料里**其它**结果比;
      同名头已存在 -> 只能算"多一个版本"; 否则算"新曲名"。

用法: py -3.13 tools/expand_yield.py [日志=train-work/artist_expand.log]
产物: 屏幕摘要 + train-work/expand_yield.tsv
"""
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LOG = sys.argv[1] if len(sys.argv) > 1 else "train-work/artist_expand.log"
ZW = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]")


def head(name):
    b = ZW.sub("", name.split("__")[0])
    return re.split(r"[（(\s　【\[《]", b)[0].strip() or b.strip()


# 本轮转写的目录名(从日志里抓 "[n/389] 名字: ...")
done = []
for ln in open(LOG, encoding="utf-8", errors="replace"):
    m = re.match(r"\[(\d+)/\d+\] (.+?): ", ln.strip())
    if m:
        done.append(m.group(2))

RD = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]
existing = set()
for rd in RD:
    for f in glob.glob(f"{rd}/*.txt"):
        existing.add(head(os.path.basename(f)[:-4]))

newh, oldh = set(), set()
rows = []
for d in done:
    h = head(d)
    is_new = h not in existing
    (newh if is_new else oldh).add(h)
    rows.append((d, h, "新曲名" if is_new else "已有同名"))
with open("train-work/expand_yield.tsv", "w", encoding="utf-8") as f:
    f.write("目录\t曲名头\t判定\n")
    for r in rows:
        f.write("\t".join(r) + "\n")

print(f"本轮转写 {len(done)} 份, 涉及曲名 {len(newh)+len(oldh)} 个")
print(f"  **新曲名 {len(newh)} 个** ({100.0*len(newh)/max(1,len(newh)+len(oldh)):.1f}%)")
print(f"  已有同名 {len(oldh)} 个 (只多了一个版本)")
print(f"-> train-work/expand_yield.tsv")
