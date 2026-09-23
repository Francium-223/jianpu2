# -*- coding: utf-8 -*-
"""纯度判据(含新的 staff>=5 硬条件)的回归测试 + 全库影响盘点。

两类输出:
  ① 已知案例是否判对(混六线谱该拒 / 纯简谱该放行)
  ② 全库已转写的页里, 有多少会被新硬条件改判为"非纯"(= 下次 finalize 会移出隔离的数量)
用法: py -3.13 tools/test_staffhard.py [全库盘点抽样数, 默认0=全查]
"""
import glob
import os
import sys
from collections import Counter

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import batch_transcribe as BT
import jp_transcribe as JP

CASES = [
    ("平淡(混六线谱, 该拒)", "平淡__jianpucn-54356", False),
    ("彩虹(抽检x17%, 该拒)", "彩虹__jianpucn-9766", False),
    ("倔强(纯简谱, 该放行)", "五月天 倔强__jianpucn-135717", True),
    ("爱p2(纯简谱, 该放行)", "爱__qupu123-380781", True),
    ("云宫迅音(官方谱, 该放行)", "云宫迅音__qupu123-363924", True),
]

idx = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        idx[BT.safe_name(os.path.basename(d))] = d

print("=== ① 已知案例 ===")
ok = 0
for label, key, want_pure in CASES:
    d = idx.get(key)
    if not d:
        print(f"  ? {label}  目录没找到")
        continue
    p = BT.pick_page(d)
    got_pure = not JP.is_impure(p)
    mark = "✓" if got_pure == want_pure else "✗"
    if got_pure == want_pure:
        ok += 1
    print(f"  {mark} {label:26s} -> {'纯简谱(转)' if got_pure else '非纯(拒)'}")
print(f"  {ok}/{len(CASES)} 符合预期")

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
files = [f for f in sorted(glob.glob("batch-out/*.txt"))
         if not os.path.basename(f).startswith("hot_")]
if LIMIT:
    files = files[:LIMIT]
print(f"\n=== ② 全库影响盘点: 查 {len(files)} 页 ===")
would_drop = []
dist = Counter()
for i, f in enumerate(files, 1):
    name = os.path.basename(f)[:-4]
    d = idx.get(name)
    if not d:
        continue
    try:
        p = BT.pick_page(d)
        if not p:
            continue
        nl, _wd = JP._nline_big(p)
        st = JP._staff_evidence(p)
        dist[min(st, 8)] += 1
        if st >= 5 and nl < 5:          # 新硬条件才会改判的那些(nline>=5 的本来就拒)
            tk = open(f, encoding="utf-8", errors="replace").read().split()
            nx = sum(1 for t in tk if "x" in t)
            would_drop.append((st, len(tk), nx, name))
    except Exception:
        continue
    if i % 1000 == 0:
        print(f"  {i}/{len(files)}  将改判 {len(would_drop)}", flush=True)

print("  谱线证据分布: " + "  ".join(f"{k}:{dist[k]}" for k in sorted(dist)))
n_drop = len(would_drop)
tok = sum(r[1] for r in would_drop)
nx = sum(r[2] for r in would_drop)
print(f"\n  新硬条件将改判为'非纯'的: {n_drop} 页 ({100*n_drop/max(len(files),1):.1f}%)")
print(f"  这些页的 token {tok}, x {nx}, x 率 {100*nx/max(tok,1):.2f}%")
print(f"  它们会在**下次 finalize** 时自动移出语料(无需额外操作 ✓)")
for st, ntok, nx2, name in sorted(would_drop, reverse=True)[:12]:
    print(f"    staff={st:2d}  token {ntok:5d}  x {nx2:4d}  {name[:52]}")
