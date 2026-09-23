# -*- coding: utf-8 -*-
"""量"没有 skill 的基线": 同一批查询, 只把匹配算法换成朴素做法, 看差多少。

三个口径(查询/语料/判定完全相同, 只有算法不同):
  A 精确子串   : `str.find` —— 最朴素的"查歌", 库里必须**原样**出现这段片段。
  B 编辑距离   : 每份谱算 Levenshtein(片段 vs 全长) —— "通用"文本相似度做法, 不看局部。
  C 本 skill   : 滑窗 Hamming(允许片段出现在任意位置) + 相邻音容错 + 同名版本归组 + 并列破平。

用法: py -3.13 eval_baseline.py [--n 0=全量] [--lens 11,15] [--errs 0,1]
"""
import argparse
import json
import os
import random
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lookup import group_of, pitch_and_oct  # noqa: E402
from eval_golden import norm, same  # noqa: E402


def lev(a, b):
    """Levenshtein。只用来做基线, 不做优化。"""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(HERE, "data.jsonl"))
    ap.add_argument("--list", default=r"D:\Documents_D\jianpu2\train-work\mandopop_list.txt")
    ap.add_argument("--lens", default="11,15")
    ap.add_argument("--errs", default="0,1")
    ap.add_argument("--n", type=int, default=262, help="每口径抽查多少首歌(0=全部)")
    ap.add_argument("--seed", type=int, default=20260923)
    a = ap.parse_args()
    rnd = random.Random(a.seed)

    rows = [json.loads(l) for l in open(a.data, encoding="utf-8") if l.strip()]
    ent = []
    for r in rows:
        p, _ = pitch_and_oct(r.get("score"))
        if len(p) >= 24:
            ent.append((r, p))
    want = [ln.strip() for ln in open(a.list, encoding="utf-8") if ln.strip() and not ln.startswith("#")]
    wn = {norm(w) for w in want}
    hits = {}
    for r, p in ent:
        gn = norm(group_of(r.get("title")))
        for w in wn:
            if same(gn, w):
                hits.setdefault(w, []).append((r, p))
                break
    keys = sorted(k for k, v in hits.items() if any(len(p) >= 15 for _, p in v))
    if a.n:
        keys = keys[:a.n]
    idx = [(r, p, np.frombuffer(p.encode(), dtype=np.uint8)) for r, p in ent]
    print(f"查询 {len(keys)} 首; 索引 {len(idx)} 份谱")

    for L in [int(x) for x in a.lens.split(",")]:
        for k in [int(x) for x in a.errs.split(",")]:
            a1 = a3 = a5 = b1 = b3 = b5 = c1 = c3 = c5 = n = 0
            for w in keys:
                vers = [v for v in hits[w] if len(v[1]) >= L]
                if not vers:
                    continue
                r0, p0 = rnd.choice(vers)
                i0 = rnd.randrange(0, len(p0) - L + 1)
                frag = list(p0[i0:i0 + L])
                for _x in range(k):
                    j = rnd.randrange(L)
                    d = int(frag[j])
                    cs = [x for x in (d - 1, d + 1) if 1 <= x <= 7]
                    if cs:
                        frag[j] = str(rnd.choice(cs))
                q = "".join(frag)
                qa = np.frombuffer(q.encode(), dtype=np.uint8)
                n += 1

                # A 精确子串
                sa = [(0 if q in p2 else 1, norm(group_of(r2.get("title")))) for r2, p2, _ in idx]
                sa.sort(key=lambda x: x[0])
                # B 编辑距离(片段 vs 每份谱全长)
                sb = sorted((lev(q, p2), norm(group_of(r2.get("title")))) for r2, p2, _ in idx)
                # C skill: 滑窗 Hamming
                sc = []
                for r2, p2, ar in idx:
                    if len(ar) < L:
                        continue
                    wnd = np.lib.stride_tricks.sliding_window_view(ar, L)
                    sc.append((int((wnd != qa).sum(axis=1).min()), norm(group_of(r2.get("title")))))
                sc.sort(key=lambda x: x[0])

                for sc_, box in ((sa, "a"), (sb, "b"), (sc, "c")):
                    top1 = sc_[0][1] if sc_ else ""
                    t3 = [x[1] for x in sc_[:3]]
                    t5 = [x[1] for x in sc_[:5]]
                    if box == "a":
                        a1 += same(top1, w); a3 += any(same(x, w) for x in t3); a5 += any(same(x, w) for x in t5)
                    elif box == "b":
                        b1 += same(top1, w); b3 += any(same(x, w) for x in t3); b5 += any(same(x, w) for x in t5)
                    else:
                        c1 += same(top1, w); c3 += any(same(x, w) for x in t3); c5 += any(same(x, w) for x in t5)
            if not n:
                continue
            print(f"\nL={L} 错音={k}  查询 {n}")
            print(f"   A 精确子串匹配 : Top1 {a1/n*100:>5.1f}%  Top3 {a3/n*100:>5.1f}%  Top5 {a5/n*100:>5.1f}%")
            print(f"   B 编辑距离     : Top1 {b1/n*100:>5.1f}%  Top3 {b3/n*100:>5.1f}%  Top5 {b5/n*100:>5.1f}%")
            print(f"   C 本 skill     : Top1 {c1/n*100:>5.1f}%  Top3 {c3/n*100:>5.1f}%  Top5 {c5/n*100:>5.1f}%")


if __name__ == "__main__":
    main()
