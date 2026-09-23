# -*- coding: utf-8 -*-
"""量化"混合谱漏网"问题: 全库已转写的页里, 有多少页带强谱线证据(六线谱/五线谱)?

背景(2026-09-21 抽检发现): 吉他弹唱谱《平淡》被转出来了, token 里满是 x —— 它在读
**六线谱的品格数字** ✗。根因是纯度门被我改成 AND(nline>=5 且 谱线证据>=4) 以换取
"不误杀纯简谱页", 代价就是**带六线谱但 nline 不足 5 的混合页会溜进来** ✗。

本工具只测量: 对每页抽首图算 jp_transcribe._staff_evidence(与管线同一个函数, 不另写 ✗),
按证据值分档, 并统计各档的 x 率 —— 若"证据高"的档 x 率明显更高, 就证实了漏网污染。

用法: py -3.13 tools/scan_mixed.py [抽样数, 默认2000]
"""
import glob
import os
import random
import sys
import time
from collections import defaultdict

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import batch_transcribe as BT
import jp_transcribe as JP

N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 2000

idx = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        idx[BT.safe_name(os.path.basename(d))] = d

files = [f for f in sorted(glob.glob("batch-out/*.txt"))
         if not os.path.basename(f).startswith("hot_")]
random.seed(7)
random.shuffle(files)
files = files[:N]

buckets = defaultdict(lambda: [0, 0, 0])   # 证据 -> [页数, token 总数, x 总数]
t0 = time.time()
done = 0
for i, f in enumerate(files, 1):
    name = os.path.basename(f)[:-4]
    d = idx.get(name)
    if not d:
        continue
    try:
        p = BT.pick_page(d)
        if not p:
            continue
        ev = JP._staff_evidence(p)
        tk = open(f, encoding="utf-8", errors="replace").read().split()
        nx = sum(1 for t in tk if "x" in t)
        b = buckets[min(ev, 10)]
        b[0] += 1
        b[1] += len(tk)
        b[2] += nx
        done += 1
    except Exception:
        continue
    if i % 500 == 0:
        el = time.time() - t0
        print(f"  {i}/{len(files)}  已查 {done}  ({el/i:.2f}s/页, 还要 {(len(files)-i)*el/i/60:.0f} 分钟)",
              flush=True)

print(f"\n共检查 {done} 页（按谱线证据分档；证据>=4 = 旧判据会拒、新 AND 判据会放行）")
print(f"{'证据':>4} {'页数':>6} {'token合计':>10} {'x合计':>8} {'x率':>7}")
tot_hi = [0, 0, 0]
tot_lo = [0, 0, 0]
for k in sorted(buckets):
    n, nt, nx = buckets[k]
    print(f"{k:>4} {n:>6} {nt:>10} {nx:>8} {100*nx/max(nt,1):>6.2f}%")
    if k >= 4:
        for j in range(3):
            tot_hi[j] += buckets[k][j]
    else:
        for j in range(3):
            tot_lo[j] += buckets[k][j]
print()
print(f"证据 >=4（强谱线, 疑似混合谱）: {tot_hi[0]} 页, x 率 {100*tot_hi[2]/max(tot_hi[1],1):.2f}%")
print(f"证据 <4 （干净）              : {tot_lo[0]} 页, x 率 {100*tot_lo[2]/max(tot_lo[1],1):.2f}%")
