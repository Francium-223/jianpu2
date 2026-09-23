# -*- coding: utf-8 -*-
"""验证"定向重跑"的等价性: 阈值 12->8 是**纯放宽**(只会多出 dash 块),
所以**没有新增 dash 候选的谱, 转写输出应逐字节相同** —— 若成立, 就只需重跑受影响的谱。

做法: 随机抽 N 个语料谱, 在**同一个进程**里用两种阈值各 render 一遍(只加载一次模型),
逐字节比较 token 序列; 同时用 test_dashminw 的 CPU 计数分出"该不该受影响"。

用法: py -3.13 tools/check_dash_equiv.py [抽样数, 默认6]
"""
import glob
import os
import random
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("JP_NOPNG", "1")
import jp_transcribe as JP
import batch_transcribe as BT
from test_dashminw import count_dash, load

N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 6

idx = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        idx[BT.safe_name(os.path.basename(d))] = d
names = [os.path.basename(f)[:-4] for f in sorted(glob.glob("batch-out/*.txt"))
         if not os.path.basename(f).startswith("hot_")]
random.seed(2026)
random.shuffle(names)

rows = []
for nm in names:
    d = idx.get(nm)
    if not d:
        continue
    try:
        p = BT.pick_page(d)
    except Exception:
        continue
    if not p:
        continue
    rows.append((nm, p))
    if len(rows) >= N:
        break

print(f"抽 {len(rows)} 个谱, 同一进程内两阈值各转一遍（只加载一次模型）\n", flush=True)
same = diff = 0
for nm, p in rows:
    os.environ["JP_DASHMINW"] = "12"
    a, _ = JP.render(p, "train-work/gt_eval/_eq.png")
    n12 = count_dash(load(p))
    os.environ["JP_DASHMINW"] = "8"
    b, _ = JP.render(p, "train-work/gt_eval/_eq.png")
    n8 = count_dash(load(p))
    ok = (a == b)
    same += ok
    diff += (not ok)
    tag = "新增dash候选" if n8 > n12 else "无新增候选"
    print(f"  {'逐字节相同 ✓' if ok else '不同 ✗'}  dash {n12}->{n8} ({tag})  "
          f"token {len(a)}->{len(b)}  {nm[:46]}", flush=True)

print(f"\n逐字节相同 {same} / 不同 {diff}")
print("  => 若'无新增候选'的谱全部相同, 且'有新增候选'的谱才有差异, "
      "则定向重跑(只重跑有新增候选的谱)与整库重跑**结果等价** ✓")
