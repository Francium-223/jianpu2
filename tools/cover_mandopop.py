# -*- coding: utf-8 -*-
"""量 jianpu2 语料对"华语流行金曲清单"的覆盖率 —— 这是 Top100 检索准确率的天花板。

严格 = 归一化后完全相等;  宽松 = 清单名 是 语料名 的子串(可含"简谱"等后缀/前缀)。
同时把 batch-out(已抓到未入库) 也算作"已覆盖", 分开报。
输出: train-work/mandopop_cover.tsv + train-work/mandopop_missing.txt
"""
import glob
import io
import os
import re
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

ZW = dict.fromkeys(map(ord, "\u200b\u200c\u200d\ufeff\u2060"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|]+")
BRACKET = re.compile(r"[（(\s　【\[《/].*$")


def norm(s):
    s = s.translate(ZW)
    s = DROP.sub("", s)
    return s.casefold()


def songs(root):
    out = {}
    for f in glob.glob(os.path.join(root, "*.txt")):
        name = os.path.basename(f)[:-4]
        base = name.split("__")[0]
        head = BRACKET.sub("", base) or base
        for cand in (norm(base), norm(head)):
            if cand:
                out.setdefault(cand, []).append(name)
    return out


lib = songs("jianpu-db-out/scores")
new = songs("batch-out")
print(f"语料(已入库) 谱 {sum(len(v) for v in lib.values())} / 去重名 {len(lib)}")
print(f"batch-out(未入库) 谱 {sum(len(v) for v in new.values())} / 去重名 {len(new)}\n")

rows, missing = [], []
strict = loose = pend = 0
for line in io.open("train-work/mandopop_list.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    parts = line.split("\t")
    title = parts[0].strip()
    artist = parts[1].strip() if len(parts) > 1 else ""
    q = norm(title)
    if q in lib:
        strict += 1
        rows.append((title, artist, "严格", len(lib[q]), lib[q][0]))
    else:
        hit = [k for k in lib if q and q in k]
        if hit:
            loose += 1
            rows.append((title, artist, "宽松", len(hit), lib[hit[0]][0]))
        elif any(q and q in k for k in new):
            pend += 1
            k = [k for k in new if q in k][0]
            rows.append((title, artist, "待入库", len(new[k]), new[k][0]))
        else:
            missing.append((title, artist))
            rows.append((title, artist, "缺", 0, ""))

total = len(rows)
print(f"{'歌名':<22}{'歌手':<12}{'判定':<8}{'版本':<6}语料中的名字")
for t, a, v, n, nm in rows:
    flag = "  " if v in ("严格", "待入库") else ("~~" if v == "宽松" else "!!")
    print(f"{flag}{t:<20}{a:<12}{v:<8}{n if n else '':<6}{nm[:40]}")

print(f"\n清单共 {total} 首")
print(f"  严格命中 {strict}  宽松命中 {loose}  已抓待入库 {pend}  缺失 {len(missing)}")
print(f"  覆盖(严格)     {strict}/{total} = {strict/total*100:.1f}%")
print(f"  覆盖(含宽松)   {strict+loose}/{total} = {(strict+loose)/total*100:.1f}%")
print(f"  覆盖(含待入库) {strict+loose+pend}/{total} = {(strict+loose+pend)/total*100:.1f}%")

with io.open("train-work/mandopop_cover.tsv", "w", encoding="utf-8") as f:
    for t, a, v, n, nm in rows:
        f.write(f"{t}\t{a}\t{v}\t{n}\t{nm}\n")
# **不要写回 mandopop_missing.txt** —— 那是爬虫的输入名单(97 首已确认缺口), 本脚本跑的时候
# 转写可能还没完成, 已抓到但未入库的谱会被重新判成"缺", 一写就把输入名单改坏了(2026-09-22 踩过)。
with io.open("train-work/mandopop_cover_missing.txt", "w", encoding="utf-8") as f:
    for t, a in missing:
        f.write(f"{t}\t{a}\n")
print("\n写出 train-work/mandopop_cover.tsv 与 mandopop_cover_missing.txt")
print("缺失前 40 首: " + " / ".join(t for t, _ in missing[:40]))
