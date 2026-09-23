# -*- coding: utf-8 -*-
"""酷狗 Top100 缺口现状: 逐首查"库里有没有 / 图下过没 / 正在爬"。

判"库里有没有"只看曲名(去掉括号副标题), 因为 eval 的命中判定也是按曲名的。
"""
import glob
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")

db = set()
for f in glob.glob(r"D:\Documents_D\jianpu-db\scores\*.txt"):
    n = os.path.basename(f)[:-4]
    if n.endswith("_expand"):
        continue
    db.add(n)
have_txt = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
dirs = [(os.path.basename(os.path.dirname(d)), os.path.basename(d))
        for d in glob.glob("images-prep/*/*") if os.path.isdir(d)]

items = []
for ln in io.open("train-work/eval_set_kugou_hualiu_2025.tsv", encoding="utf-8"):
    s = ln.rstrip("\n")
    if s and not s.startswith("#"):
        c = s.split("\t")
        if len(c) >= 3:
            items.append((c[0], c[1], c[2]))


def in_db(title):
    t = re.sub(r"[（(].*?[)）]", "", title).strip() or title
    if t in db:
        return True
    for n in db:
        if n == t or (len(t) >= 4 and (n.startswith(t) or t.startswith(n))):
            return True
    return False


ok, imgs, none = [], [], []
for rank, title, artist in items:
    t = re.sub(r"[（(].*?[)）]", "", title).strip() or title
    cands = [n for _b, n in dirs if t in n]
    if in_db(title):
        ok.append((rank, title, artist))
    elif cands:
        imgs.append((rank, title, artist, len(cands)))
    else:
        none.append((rank, title, artist))

print(f"榜单 {len(items)} 首: 库里已有 {len(ok)} | 有图待转 {len(imgs)} | 无图 {len(none)}\n")
print("=== A. 有图待转写(爬完就能补) ===")
for r, t, a, n in imgs:
    print(f"  #{r:<3} {t:<14} {a:<14} ({n} 个目录)")
print(f"\n=== B. 库里/爬取目录都没有(需现爬或源站确实没有) ===")
for r, t, a in none:
    print(f"  #{r:<3} {t:<14} {a}")
print("\n=== 周杰伦的歌逐首 ===")
for r, t, a in items:
    if "周杰伦" in a:
        t2 = re.sub(r"[（(].*?[)）]", "", t).strip() or t
        cands = [n for _b, n in dirs if t2 in n]
        st = "库里已有" if in_db(t) else (f"有图待转({len(cands)})" if cands else "都没有")
        print(f"  #{r:<3} {t:<14} {st}")
