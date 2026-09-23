# -*- coding: utf-8 -*-
"""量化"转写开头出现长同音串"的现象 —— 疑似把页眉装饰(黑框/二维码/logo)读成了音符。

判据: 一首谱的音高串**开头**有多长的连续同音? 与"串内部"的长同音率对比。
若开头显著更高, 说明是版面顶部装饰导致的系统性伪影(它会让检索产生假命中:
2026-09-22 用户实测题 `11117535` 就因此并列到一首无关歌)。
"""
import glob
import io
import os
import sys
from collections import Counter

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

SKIP = "0x"


def pitch(f):
    e, _ = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    return "".join(x[0] for x in e if x[0] not in SKIP)


files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
print(f"扫描 batch-out {len(files)} 份\n")

head_run = Counter()          # 开头连续同音的长度
ex = []
n_all = n_mid = 0
mid_run = Counter()
for f in files:
    s = pitch(f)
    if len(s) < 12:
        continue
    k = 1
    while k < len(s) and s[k] == s[0]:
        k += 1
    head_run[k] += 1
    if k >= 4:
        ex.append((k, os.path.basename(f)[:-4], s[:16]))
    # 串内部(从第 4 个音起)的最长同音串, 作为对照
    best = cur = 1
    for i in range(4, len(s)):
        cur = cur + 1 if s[i] == s[i - 1] else 1
        best = max(best, cur)
    mid_run[best] += 1
    n_all += 1

tot = n_all
print("开头连续同音长度分布:")
for k in sorted(head_run):
    if k >= 3:
        print(f"   >= {k:>2}: {sum(v for kk, v in head_run.items() if kk >= k):>5} 份 "
              f"({sum(v for kk, v in head_run.items() if kk >= k)/tot*100:>5.1f}%)")
print(f"\n开头 >=4 同音: {sum(v for k, v in head_run.items() if k >= 4)} 份 "
      f"({sum(v for k, v in head_run.items() if k >= 4)/tot*100:.1f}%)")
print(f"串内部 >=4 同音: {sum(v for k, v in mid_run.items() if k >= 4)} 份 "
      f"({sum(v for k, v in mid_run.items() if k >= 4)/tot*100:.1f}%)")
print("\n开头同音 >=5 的例(长度, 文件, 开头音):")
for k, b, s in sorted(ex, reverse=True)[:14]:
    if k >= 5:
        print(f"   {k:>2}  {b[:52]:<54} {s}")
