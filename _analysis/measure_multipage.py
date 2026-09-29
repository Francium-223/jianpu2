# -*- coding: utf-8 -*-
"""实测: 图库里"多页简谱"有多少 —— 现在管线只用**一页**(pick_page 只挑一张),
多页谱的成品因此是**半首**。本脚本只读, 数清楚盘子有多大。

判定"谱页"用与 pick_page 相同的特征: 竖版(h/w>=1.3)、宽高>100、文件名不含 __pg。
只统计还没有转录稿的会重复计, 所以分"全部"和"成品已受影响的"两组。
用法: py -3.13 _analysis/measure_multipage.py
"""
import collections
import json
import os
import re

ROOT = r"D:\Documents_D\jianpu2"
IMG_ROOTS = [os.path.join(ROOT, "images-prep"), os.path.join(ROOT, "images")]
BOUT = os.path.join(ROOT, "batch-out")
DATA = r"D:\Documents_D\jianpu-db\data.jsonl"
EXTS = (".jpg", ".jpeg", ".png")


def pages(d):
    out = []
    for f in os.listdir(d):
        if os.path.splitext(f)[1].lower() not in EXTS or "__pg" in f:
            continue
        out.append(os.path.join(d, f))
    return out


def portrait(p):
    try:
        from PIL import Image
        w, h = Image.open(p).size
    except Exception:
        return False
    return w > 100 and h > 100 and h / max(w, 1) >= 1.3


dirs = []
for root in IMG_ROOTS:
    if not os.path.isdir(root):
        continue
    for d in sorted(os.listdir(root)):
        p = os.path.join(root, d)
        if not os.path.isdir(p):
            continue
        if "__" in d:
            dirs.append(p)
            continue
        for e in sorted(os.listdir(p)):
            q = os.path.join(p, e)
            if os.path.isdir(q) and "__" in e:
                dirs.append(q)

have = {os.path.splitext(f)[0] for f in os.listdir(BOUT) if f.endswith(".txt")}
multi, by_src = [], collections.Counter()
tot = 0
for d in dirs:
    ps = pages(d)
    if len(ps) < 2:
        continue
    np_ = sum(1 for p in ps if portrait(p))
    if np_ < 2:
        continue
    tot += 1
    multi.append((os.path.basename(d), np_))
    src = re.search(r"__([A-Za-z0-9_]+)", os.path.basename(d))
    by_src[src.group(1) if src else "?"] += 1

affected = [m for m in multi if m[0] in have]
print(f"图库目录 {len(dirs)} 个")
print(f"**多页谱** {tot} 个 (>=2 张竖版谱页) —— 这些现在的成品只覆盖其中一页")
print(f"   其中已有转录稿(成品已被截断) {len(affected)} 个")
print("按源:")
for s, n in by_src.most_common(12):
    print(f"   {s:<14}{n:>6}")

songs = sum(1 for _ in open(DATA, encoding="utf-8"))
print(f"\n语料 {songs} 首 —— 受影响上限 {len(affected)} 首 ({len(affected)/max(songs,1)*100:.1f}%)")

with open(os.path.join(ROOT, "_analysis", "multipage_dirs.txt"), "w", encoding="utf-8") as f:
    for n, k in sorted(multi, key=lambda x: -x[1]):
        f.write(f"{k}\t{n}\n")
print("清单 -> _analysis/multipage_dirs.txt")
print("页数最多的 8 个:")
for n, k in sorted(multi, key=lambda x: -x[1])[:8]:
    print(f"   {k} 页  {n[:70]}")
