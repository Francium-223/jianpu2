# -*- coding: utf-8 -*-
"""回收"旧判据误杀"的谱(只回收**质量门通过**的, 宁缺毋滥)。

背景: 旧判据是 `nline>=5 即非纯`, 会被**黑色标题底框/长连音线**骗(实测《倔强》纯简谱 nline=26
全来自标题框)。现行判据是 `nline>=5 且 staff>=4, 或 staff>=5`。所以 batch-out-bad 里有一批
真简谱被历史误杀 —— 直接压覆盖率(《铁血丹心》就是这样)。

**为什么不能整批回收**: readmit_list 里的 132 份"按现行判据应放行"混着大量编配谱
—— `钢琴伴奏谱 nline=670 staff=2`、`指弹 nline=751`、`总谱完美版 nline=910`(staff 检测器对
厚五线谱失灵)。整批放行会污染语料。

质量门(全部要过):
  1. nline <= 40          —— 排除上百条横线的钢琴/总谱
  2. staff <= 3
  3. 已有转写结果里 x(念白)率 < 10%   —— 念白率高 = 在读六线谱品格数字
  4. 已有转写结果的音符数 >= 30       —— 太短没法判断, 且贡献有限
可逆: 只搬不删, 每条记 train-work/readmit_applied.log。
用法: py -3.13 tools/readmit_apply.py [--dry]
"""
import glob
import io
import os
import re
import shutil
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DRY = "--dry" in sys.argv

DIG = "1234567"


def stats(path):
    toks = [t for t in io.open(path, encoding="utf-8", errors="replace").read().split()
            if t and not t.startswith("%") and "=" not in t]
    n = len(toks)
    if not n:
        return 0, 1.0
    nx = sum(1 for t in toks if "x" in t)
    nd = sum(1 for t in toks if t.rstrip(".'-") and t.rstrip(".'-")[-1] in DIG)
    return nd, nx / n


# 候选来自 readmit_check.py: 标题命中金曲清单 + 按现行判据应放行
rows = []
for line in io.open("train-work/readmit_list.txt", encoding="utf-8"):
    b = line.strip()
    if b:
        rows.append(b)

cand = []
for b in rows:
    f = f"batch-out-bad/{b}.txt"
    if not os.path.exists(f):
        continue
    nd, xr = stats(f)
    cand.append((b, nd, xr))

print(f"readmit_list {len(rows)} 份; 有 txt 的 {len(cand)} 份")
# 需要 nline/staff 才能判 -> 从 pick_best/kind2 里读
k2 = {}
for line in io.open("train-work/kind2.tsv", encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 7 and p[0] != "dir":
        try:
            k2[p[0]] = (int(p[1]), int(p[6]))          # (nline, staff)
        except Exception:
            pass

passed, rejected = [], []
for b, nd, xr in cand:
    nl, st = k2.get(b, (999, 999))
    ok = nl <= 40 and st <= 3 and xr < 0.10 and nd >= 30
    (passed if ok else rejected).append((b, nl, st, nd, xr))

print(f"\n通过质量门 {len(passed)} 份 / 被拒 {len(rejected)} 份")
print("\n通过(将搬回 batch-out):")
for b, nl, st, nd, xr in passed[:40]:
    print(f"   nline={nl:>4} staff={st:>2} 音符={nd:>4} x率={xr*100:>4.1f}%  {b[:56]}")
if len(passed) > 40:
    print(f"   ... 另外 {len(passed)-40} 份")
print("\n被拒(例):")
for b, nl, st, nd, xr in rejected[:12]:
    print(f"   nline={nl:>4} staff={st:>2} 音符={nd:>4} x率={xr*100:>4.1f}%  {b[:56]}")

if DRY:
    print("\n(空跑, 未搬)")
    sys.exit(0)

log = io.open("train-work/readmit_applied.log", "a", encoding="utf-8")
n = 0
for b, nl, st, nd, xr in passed:
    moved = []
    for ext in (".txt", ".png", ".jpg", ".jpeg"):
        src = f"batch-out-bad/{b}{ext}"
        dst = f"batch-out/{b}{ext}"
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.move(src, dst)
            moved.append(ext)
    if moved:
        n += 1
        log.write(f"{b}\tnline={nl}\tstaff={st}\tnotes={nd}\txrate={xr:.3f}\t{','.join(moved)}\n")
        log.flush()
print(f"\n搬回 {n} 份 -> batch-out (日志 train-work/readmit_applied.log)")
