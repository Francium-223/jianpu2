# -*- coding: utf-8 -*-
"""酷狗 Top100 的缺口: 是"没下过图"还是"下了没转写"?

对每首歌, 在 images-prep 的所有下载目录里找"目录名包含该歌名"的:
  * 找到且 batch-out 里已有产物 -> 已转写(应该在库里; 若库里没有则是别的问题)
  * 找到但 batch-out 没产物      -> **下了没转写**(最容易补的一类)
  * 找不到                       -> 没下过图(要重新爬)
"""
import glob
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = r"D:\Documents_D\jianpu2"
os.chdir(ROOT)
LIST = "train-work/eval_set_kugou_hualiu_2025.tsv"

# 已转写的产物名(transcribe_source.py 的幂等键)
have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
# 也把已入库的曲名收进来(有些来自别的批次)
db = {os.path.basename(f)[:-4] for f in glob.glob(r"D:\Documents_D\jianpu-db\scores\*.txt")
      if not f.endswith("_expand.txt")}

# 下载目录索引: 目录名 -> 批次
dirs = []
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        dirs.append((os.path.basename(os.path.dirname(d)), os.path.basename(d)))

items = []
for ln in io.open(LIST, encoding="utf-8"):
    s = ln.rstrip("\n")
    if s and not s.startswith("#"):
        c = s.split("\t")
        if len(c) >= 3:
            items.append((c[0], c[1], c[2]))

down_not_trans, not_down, in_db = [], [], []
for rank, title, artist in items:
    t = re.sub(r"[（(].*?[)）]", "", title).strip() or title      # 去括号副标题
    cands = [(b, n) for b, n in dirs if t in n]
    if any(any(t in x for x in db) or any(x.startswith(t) for x in db) for x in [db]):
        in_db.append((rank, title, artist))
        continue
    if not cands:
        not_down.append((rank, title, artist))
        continue
    trans = [n for _b, n in cands if n in have or any(n.startswith(h) for h in ())]
    pending = [(b, n) for b, n in cands if n not in have]
    if len(pending) < len(cands):
        in_db.append((rank, title, artist))
    else:
        down_not_trans.append((rank, title, artist, pending[:3]))

print(f"榜单 {len(items)} 首")
print(f"  已入库   {len(in_db)}")
print(f"  下了没转写 {len(down_not_trans)}   <- 最容易补的一类")
for r, t, a, p in down_not_trans:
    print(f"     #{r:<3} {t:<14} {a:<12} {[x[1][:34] for x in p]}")
print(f"  没下过图  {len(not_down)}")
for r, t, a in not_down:
    print(f"     #{r:<3} {t:<14} {a}")
