# -*- coding: utf-8 -*-
"""「同曲多版本里这一版有多"孤立"」的分布 —— 想用它自动抓《你怎么说》那类**拼接假片段**。

做法: 只取有 ≥2 个版本的曲名; 对每个版本算它的 W 音窗口里"兄弟版本都没有"的比例(独有率)。
问题: 这个比例的分辨力够不够? 拿已知的坏样本(你怎么说_2)看它排在第几百分位。

用法: py -3.13 _analysis/unique_ratio_dist.py [--w 11]
"""
import argparse
import collections
import glob
import io
import json
import os
import re
import sys

ROOT = r"D:\Documents_D\jianpu2"
K = 999          # 只看 top-K 名次里有没有坏样本


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--w", type=int, default=11)
    ap.add_argument("--each", type=int, default=400, help="每组最多细算几个版本(省时间)")
    a = ap.parse_args()
    W = a.w
    sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
    from lookup import pitch_and_oct

    groups = collections.defaultdict(list)
    for line in io.open(r"D:\Documents_D\jianpu-db\data.jsonl", encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        p, _ = pitch_and_oct(d.get("score") or "")
        t = (d.get("title") or "").strip()
        if t and len(p) >= W:
            groups[t].append(((d.get("file") or [""])[0], d.get("status") or "", p))

    rows = []
    for t, vs in groups.items():
        if len(vs) < 2:
            continue
        for i, (f, st, p) in enumerate(vs[:a.each]):
            others = set()
            for j, (f2, _s2, p2) in enumerate(vs):
                if j == i:
                    continue
                others |= {p2[k:k + W] for k in range(len(p2) - W + 1)}
            mine = [p[k:k + W] for k in range(len(p) - W + 1)]
            if not mine:
                continue
            uniq = sum(1 for w in mine if w not in others)
            rows.append((uniq / len(mine), uniq, len(mine), f, st, t))

    ratios = sorted(r[0] for r in rows)
    n = len(ratios)
    print(f"有 ≥2 版本的歌: {len({r[5] for r in rows})} 组 / 版本 {n} 份 (窗口 {W} 音)")
    for p in (0.5, 0.75, 0.9, 0.95, 0.99, 1.0):
        print(f"   独有率 {int(p*100):>3}% 分位 = {ratios[min(n-1, int(n*p))]:.3f}")
    print("\n独有率最高的 12 份(越接近 1 越像'这一版跟别的版本毫无共同片段'):")
    for r in sorted(rows, key=lambda x: -x[0])[:12]:
        print(f"   {r[0]*100:5.1f}%  {r[1]:>4}/{r[2]:<4} {r[4]:<4} {r[3][:40]:<42} {r[5][:20]}")
    hits = [r for r in rows if "你怎么说_2" in r[3]]
    for r in hits:
        rank = 1 + sum(1 for x in ratios if x > r[0])
        print(f"\n坏样本 你怎么说_2: 独有率 {r[0]*100:.1f}% ({r[1]}/{r[2]}), 排第 {rank}/{n}"
              f" = 前 {rank/n*100:.1f}%")


if __name__ == "__main__":
    main()
