# -*- coding: utf-8 -*-
"""诊断其余可疑点: 音0 谱特征 / x 分布 / 八度比例 / 时值分布合理性。"""
import glob, os, re, sys
from collections import Counter
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")

n_empty = 0
x_rows = []
low_hi = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b.startswith("hot_"):
        continue
    tk = open(f, encoding="utf-8").read().split()
    notes = [t for t in tk if NOTE.match(t)]
    if not notes:
        n_empty += 1
        continue
    nx = sum(1 for t in tk if "x" in t)
    if nx:
        x_rows.append((nx, len(notes), b))
    low = sum(t.count(",") for t in notes)
    hi = sum(t.count("'") for t in notes)
    low_hi.append((low, hi, len(notes), b))

print(f"=== 音0 谱: {n_empty} 张 ===")

print(f"\n=== 念白 'x' 分布 ===")
x_rows.sort(reverse=True)
print(f"含 x 的文件: {len(x_rows)} / {1375-n_empty} 有效谱")
print(f"x 总数: {sum(r[0] for r in x_rows)}")
b = Counter()
for nx, n, _ in x_rows:
    b["1-3"] += nx <= 3
    b["4-20"] += 4 <= nx <= 20
    b["21-100"] += 21 <= nx <= 100
    b[">100"] += nx > 100
for k in ["1-3", "4-20", "21-100", ">100"]:
    print(f"  x 个数 {k:7s}: {b[k]:5d} 个文件")
print("x 最多的 8 个:")
for nx, n, f in x_rows[:8]:
    print(f"  {nx:4d} 个x (共{n:4d}音, {100*nx/max(n,1):3.0f}%)  {f[:58]}")

print(f"\n=== 八度点比例 ===")
tl = sum(r[0] for r in low_hi); th = sum(r[1] for r in low_hi); tn = sum(r[2] for r in low_hi)
print(f"低八度 ',' : {tl:7d}  ({100*tl/tn:.1f}% 的音符带低八度)")
print(f"高八度 \"'\": {th:7d}  ({100*th/tn:.1f}% 的音符带高八度)")
print(f"低/高 比: {tl/max(th,1):.2f}")
# 低八度过多的谱(可能是歌词笔画误判)
bad = [(l, h, n, f) for l, h, n, f in low_hi if n and l / n > 0.5]
print(f"\n低八度占该谱 >50% 的谱: {len(bad)} 个 (高度可疑: 可能是歌词/杂纹误判)")
for l, h, n, f in sorted(bad, key=lambda x: -x[0] / max(x[2], 1))[:8]:
    print(f"  低{l:4d}/高{h:4d} (共{n:4d}音, {100*l/n:3.0f}%)  {f[:52]}")
