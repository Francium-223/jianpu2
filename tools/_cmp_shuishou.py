# -*- coding: utf-8 -*-
"""《爱上草原的小河》(库里) 与 三份《水手》是不是同一首?
判据: 最长公共子串 LCS + 11 音窗口重合率。"""
import glob
import io
import os
import sys
from difflib import SequenceMatcher

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

SKIP = "0x"


def pstr(path):
    e, _ = M.enc(io.open(path, encoding="utf-8", errors="replace").read())
    return "".join(x[0] for x in e if x[0] not in SKIP)


def winfrac(a, b, n=11):
    A = {a[i:i + n] for i in range(len(a) - n + 1)}
    B = {b[i:i + n] for i in range(len(b) - n + 1)}
    if not A or not B:
        return 0.0
    return 2 * len(A & B) / (len(A) + len(B))


ref = sorted(glob.glob("jianpu-db-out/scores/爱上草原的小河*.txt"))
shui = sorted(glob.glob("batch-out/水手*.txt"))
print("参照(库内):")
for f in ref:
    print("   ", f)
print("\n水手(新转):")
for f in shui:
    print("   ", f)

R = [(f, pstr(f)) for f in ref]
S = [(f, pstr(f)) for f in shui]
for fr, pr in R:
    print(f"\n== {os.path.basename(fr)}  ({len(pr)} 音)")
    for fs, ps in S:
        sm = SequenceMatcher(None, pr, ps, autojunk=False)
        m = sm.find_longest_match(0, len(pr), 0, len(ps))
        print(f"   vs {os.path.basename(fs)[:34]:<36} LCS {m.size:3d} 音 @({m.a},{m.b})"
              f"  11音窗口重合 {winfrac(pr, ps)*100:5.1f}%  长度 {len(ps)}")

# 水手三份互相之间(应有较高一致, 作为基准)
print("\n== 水手互相比对(基准)")
for i in range(len(S)):
    for j in range(i + 1, len(S)):
        a, b = S[i][1], S[j][1]
        sm = SequenceMatcher(None, a, b, autojunk=False)
        m = sm.find_longest_match(0, len(a), 0, len(b))
        print(f"   {os.path.basename(S[i][0])[:22]} vs {os.path.basename(S[j][0])[:22]}"
              f"  LCS {m.size:3d}  11音重合 {winfrac(a, b)*100:5.1f}%")

print("\n== 库内随机对照(爱上草原 vs 其他歌, 看 11 音重合的正常水平)")
import random
random.seed(0)
others = [f for f in glob.glob("jianpu-db-out/scores/*.txt") if "爱上草原" not in f]
for f in random.sample(others, 5):
    po = pstr(f)
    print(f"   {os.path.basename(f)[:36]:<38} 11音重合 {winfrac(R[0][1], po)*100:5.1f}%")
