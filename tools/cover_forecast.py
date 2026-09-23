# -*- coding: utf-8 -*-
"""预测 finalize 之后的**严格覆盖率**: 只有"被 pick_best 选中且当前在 batch-out"的谱才会进 scores。
(cover_mandopop.py 的"待入库"会把最终会落选的版本也算上, 偏高; 这个脚本给的是保守下界。)
"""
import glob
import io
import os
import re
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
BR = re.compile(r"[（(\s　【\[《/].*$")


def norm(s):
    return DROP.sub("", s.translate(ZW)).casefold()


# 会被留在 batch-out 的 = 当前在 batch-out 且不在落选名单里
drop = {l.strip() for l in io.open("train-work/drop_dup.txt", encoding="utf-8") if l.strip()}
keep = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)[:-4]
    if b in drop:
        continue
    keep.append(b)
print(f"batch-out {len(glob.glob('batch-out/*.txt'))} 个 txt, 扣掉落选 {len(drop)} -> 预计入库 {len(keep)}")

DIG = "1234567"


def notes_of(b):
    f = f"batch-out/{b}.txt"
    try:
        toks = [t for t in io.open(f, encoding="utf-8", errors="replace").read().split()
                if t and not t.startswith("%") and "=" not in t]
    except Exception:
        return 0
    return sum(1 for t in toks if t.rstrip(".'-") and t.rstrip(".'-")[-1] in DIG)


keys = {}                       # 归一化名 -> 该名下最长的转写音符数(衡量"这条覆盖能不能用")
for b in keep:
    base = b.split("__")[0]
    n = notes_of(b)
    for cand in (norm(base), norm(BR.sub("", base) or base)):
        if cand and n > keys.get(cand, -1):
            keys[cand] = n

rows = []
for line in io.open("train-work/mandopop_list.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    p = line.split("\t")
    t = p[0].strip()
    a = p[1].strip() if len(p) > 1 else ""
    q = norm(t)
    if q in keys:
        v, nn = "严格", keys[q]
    else:
        hit = [k for k in keys if q and q in k]
        if hit:
            v, nn = "宽松", max(keys[k] for k in hit)
        else:
            v, nn = "缺", 0
    rows.append((t, a, v, nn))

n = len(rows)
s = sum(1 for r in rows if r[2] == "严格")
lo = sum(1 for r in rows if r[2] == "宽松")
print(f"\n金曲清单 {n} 首")
print(f"  严格命中 {s} = {s/n*100:.1f}%")
print(f"  含宽松   {s+lo} = {(s+lo)/n*100:.1f}%")
print(f"  仍缺     {n-s-lo} = {(n-s-lo)/n*100:.1f}%")

# 质量分层: "有谱"不等于"有能用的谱" —— 实测有 11 音符的《光辉岁月》也算覆盖
st_ = [r for r in rows if r[2] != "缺"]
print("\n命中者的转写长度分层(检索实际吃的是音符):")
for th in (1, 30, 50, 100, 200):
    k = sum(1 for r in st_ if r[3] >= th)
    print(f"  >= {th:>3} 音符: {k:>3} 首 = {k/n*100:>5.1f}%  (占命中者的 {k/max(1,len(st_))*100:>5.1f}%)")
short = sorted([r for r in st_ if r[3] < 50], key=lambda r: r[3])
if short:
    print("\n转写过短(<50 音符, 覆盖了但检索价值低)的:")
    for t, a, v, nn in short[:15]:
        print(f"   {nn:>4} 音符  {t}  ({a})")
miss = [r[0] for r in rows if r[2] == "缺"]
print("\n仍缺: " + " / ".join(miss))
