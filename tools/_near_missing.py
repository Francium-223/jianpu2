# -*- coding: utf-8 -*-
"""排查"判定缺失"的歌是否只是名字写法不同(别名/后缀/前缀)。"""
import glob
import io
import os
import re
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
ZW = dict.fromkeys(map(ord, "\u200b\u200c\u200d\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|]+")


def norm(s):
    return DROP.sub("", s.translate(ZW)).casefold()


keys = []
for f in glob.glob("jianpu-db-out/scores/*.txt"):
    b = os.path.basename(f)[:-4].split("__")[0]
    keys.append((b, norm(b)))

print("=== 待入库 ===")
for line in io.open("train-work/mandopop_cover.tsv", encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if len(c) > 2 and c[2] == "待入库":
        print("   ", c[0], "|", c[4])

print("\n=== 宽松命中(需人工甄别真伪) ===")
for line in io.open("train-work/mandopop_cover.tsv", encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if len(c) > 2 and c[2] == "宽松":
        print(f"    {c[0]:<16} -> {c[4]}")

print("\n=== 缺失项里存在'近名'的(可能只是写法不同) ===")
n_near = 0
for line in io.open("train-work/mandopop_missing.txt", encoding="utf-8"):
    t = line.split("\t")[0].strip()
    if not t:
        continue
    q = norm(t)
    near = [b for b, k in keys if len(q) >= 2 and (q[:2] in k or (len(q) >= 3 and q[:3] in k))]
    if near:
        n_near += 1
        print(f"    {t:<18} 近名 {len(near):3d}: " + " / ".join(near[:4]))
print(f"\n缺失 {sum(1 for l in io.open('train-work/mandopop_missing.txt',encoding='utf-8') if l.strip())} 首, 其中 {n_near} 首有近名")
