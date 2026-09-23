# -*- coding: utf-8 -*-
"""分析: 已转写的 1375 张里, 有多少受"旧逻辑"影响(需要重跑)。

两类症状:
  A. 含 '?' 或 'x'  -> 文字块/排版说明被当音符(旧逻辑没做行内 y 切分)
  B. 裸数字比例高   -> 数字与下划线粘连导致时值丢失(旧 geo_detect 漏判)
"""
import glob, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")
HAS_DUR = re.compile(r"^[,']*[qsdh]")
BARE = re.compile(r"^[,']*[1-7x0][.,']*$")

files = [f for f in glob.glob("batch-out/*.txt") if not os.path.basename(f).startswith("hot_")]
print(f"总转写文件: {len(files)}")

A = []      # 含 ? 或 x
B = []      # 裸数字比例 > 60%
both = []
for f in files:
    tk = open(f, encoding="utf-8").read().split()
    if not tk:
        continue
    notes = [t for t in tk if NOTE.match(t)]
    if not notes:
        continue
    a = any("?" in t or "x" in t for t in tk)
    bare = sum(1 for t in notes if BARE.match(t))
    ratio = bare / len(notes)
    b = ratio > 0.6
    if a:
        A.append(os.path.basename(f))
    if b:
        B.append((ratio, os.path.basename(f)))
    if a and b:
        both.append(os.path.basename(f))

print(f"\nA. 含 '?'/'x' (文字块误检): {len(A)} 张")
print(f"B. 裸数字占比 >60% (时值丢失): {len(B)} 张")
print(f"两类都中: {len(both)} 张")
uni = set(A) | {n for _, n in B}
print(f"合计受影响(去重): {len(uni)} 张  ({100*len(uni)/max(len(files),1):.0f}%)")

print("\nB 类最严重的 8 个:")
for r, n in sorted(B, reverse=True)[:8]:
    print(f"  {r*100:5.0f}% 裸数字  {n[:64]}")
