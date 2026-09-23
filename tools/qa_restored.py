# -*- coding: utf-8 -*-
"""质检: 搬回的 260 个"择优胜出版"质量是否与语料基线一致(别只报数量涨了)。

指标: 音符数、念白(x)率、休止(0)率、圆滑线(~)率; 与全库 batch-out 的中位数对比。
"""
import glob
import io
import os
import re
import statistics as st
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DIG = "1234567"
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")


def norm(s):
    return DROP.sub("", re.sub(r"\[[^\]]*\]", "", s).translate(ZW)).casefold()


def stats(f):
    toks = [t for t in io.open(f, encoding="utf-8", errors="replace").read().split()
            if t and not t.startswith("%") and "=" not in t]
    n = len(toks)
    if not n:
        return None
    nd = sum(1 for t in toks if t.rstrip(".'-") and t.rstrip(".'-")[-1] in DIG)
    nx = sum(1 for t in toks if "x" in t)
    nz = sum(1 for t in toks if t.startswith("0") or t.endswith("0"))
    nt = sum(1 for t in toks if "~" in t)
    return nd, nx / n, nz / n, nt / n


restored = [l.strip() for l in io.open("train-work/lost_winners.txt", encoding="utf-8") if l.strip()]
base_files = glob.glob("batch-out/*.txt")
rest_files = [f"batch-out/{b}.txt" for b in restored if os.path.exists(f"batch-out/{b}.txt")]
print(f"搬回名单 {len(restored)} 份, 现在 batch-out 里能读到 {len(rest_files)} 份")
print(f"全库基线 batch-out {len(base_files)} 份\n")

for tag, files in (("搬回的 260", rest_files), ("全库基线", base_files)):
    S = [s for s in (stats(f) for f in files) if s]
    print(f"{tag}: n={len(S)}")
    print(f"   音符数   中位 {st.median(s[0] for s in S):>7.0f}   均值 {st.mean(s[0] for s in S):>7.1f}")
    print(f"   念白x率  中位 {st.median(s[1] for s in S)*100:>7.2f}%  均值 {st.mean(s[1] for s in S)*100:>7.2f}%")
    print(f"   休止0率  中位 {st.median(s[2] for s in S)*100:>7.2f}%  均值 {st.mean(s[2] for s in S)*100:>7.2f}%")
    print(f"   圆滑~率  中位 {st.median(s[3] for s in S)*100:>7.2f}%  均值 {st.mean(s[3] for s in S)*100:>7.2f}%")
    print()

# 金曲清单里被搬回的那些, 音符数够不够撑检索
want = [l.split("\t")[0].strip() for l in io.open("train-work/mandopop_list.txt", encoding="utf-8")
        if l.strip() and not l.startswith("#")]
print("金曲清单里被搬回的 (音符数):")
n = 0
for b in restored:
    f = f"batch-out/{b}.txt"
    if not os.path.exists(f):
        continue
    s = stats(f)
    if s and any(norm(w) and norm(w) in norm(b) for w in want):
        n += 1
        print(f"   {s[0]:>5} 音符  x率{s[1]*100:>5.1f}%   {b[:56]}")
print(f"   共 {n} 首")
