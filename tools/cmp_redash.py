# -*- coding: utf-8 -*-
"""定向重跑的前后对比: 旧转写(train-work/redash-backup) vs 新转写(batch-out)。

关键要分清两种变化:
  ① 真的多了延音杠 `-`  ✓ —— 这是本次修复的目的(阈值 12->8 是纯放宽)
  ② 别的 token 也变了   ✗ —— 那是**模型输出不确定性**造成的随机抖动, 与修复无关
若 ② 很大, 说明"重跑"本身会引入噪声, 值得警惕(见 tools/check_dash_equiv.py)。

用法: py -3.13 tools/cmp_redash.py
"""
import glob
import os
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

BK = "train-work/redash-backup"
if not os.path.isdir(BK):
    print(f"没有备份目录 {BK}（还没跑 prep 或已被清理）")
    sys.exit(0)

files = sorted(glob.glob(os.path.join(BK, "*.txt")))
print(f"备份 {len(files)} 个旧转写\n")

same = diff = no_new = 0
tok_o = tok_n = dash_o = dash_n = x_o = x_n = 0
dash_only = 0
other_changed = []
for f in files:
    nm = os.path.basename(f)
    new = os.path.join("batch-out", nm)
    if not os.path.exists(new):
        no_new += 1
        continue
    a = open(f, encoding="utf-8", errors="replace").read().split()
    b = open(new, encoding="utf-8", errors="replace").read().split()
    tok_o += len(a)
    tok_n += len(b)
    dash_o += sum(1 for t in a if t == "-")
    dash_n += sum(1 for t in b if t == "-")
    x_o += sum(1 for t in a if "x" in t)
    x_n += sum(1 for t in b if "x" in t)
    if a == b:
        same += 1
        continue
    diff += 1
    # 只多了 dash? (去掉两边的 '-' 后应完全相同)
    if [t for t in a if t != "-"] == [t for t in b if t != "-"]:
        dash_only += 1
    else:
        other_changed.append((nm, len(a), len(b)))

print(f"新旧都有: {len(files)-no_new}   逐字节相同 {same}   有差异 {diff}   缺新转写 {no_new}")
print(f"  其中【只多了延音杠】 ✓ : {dash_only}")
print(f"  其中【还有别的变化】 ✗ : {len(other_changed)}  (模型随机抖动)")
print()
print(f"延音杠总数   {dash_o} -> {dash_n}  ({dash_n-dash_o:+d})")
print(f"token 总数   {tok_o} -> {tok_n}  ({tok_n-tok_o:+d})")
print(f"x 总数       {x_o} -> {x_n}  ({x_n-x_o:+d})")
if other_changed:
    print("\n还有别的变化、且 token 数差得最多的 10 页:")
    for nm, a, b in sorted(other_changed, key=lambda r: -abs(r[2] - r[1]))[:10]:
        print(f"  {a:4d} -> {b:4d}  {nm[:60]}")
