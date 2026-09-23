# -*- coding: utf-8 -*-
"""换源效果实测: 同一首歌在不同源各转一次, 比较转写质量。

思路: 语料里的名字形如 `<歌名>__<源>-<id>`, 按歌名分组即可找到"同一首、不同源"的配对。
指标(都只是代理, 但能横向比):
  n      转写出的 token 数(同一首歌应当接近; 太少=漏读)
  x率    被判成"歌词/念白"的比例(图不清楚时模型容易把杂点读成 x) —— 越低越好
  空率   被读成 '?' 的比例 —— 越低越好
  八度率 带 / 或 , 的音符占比(简谱本来就有, 只用于横向比较)
"""
import collections
import glob
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdhc]*[,']*([1-7x?])")


def stats(path):
    toks = io.open(path, encoding="utf-8", errors="replace").read().split()
    n = len(toks)
    if not n:
        return None
    x = sum(1 for t in toks if t == "x")
    q = sum(1 for t in toks if t == "?")
    oct_ = sum(1 for t in toks if t.startswith("'") or t.startswith(","))
    return dict(n=n, x=x / n, q=q / n, oct=oct_ / n)


# 按歌名分组
groups = collections.defaultdict(dict)
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)[:-4]
    if b in ("progress", "skipped"):
        continue
    m = re.match(r"^(.*?)__([a-z0-9.]+)-(\d+)$", b)
    if not m:
        continue
    title, src, sid = m.groups()
    src = src.replace("jianpucn", "jianpucn")     # 归一
    groups[title][src] = f

# 找"jianpucn + 另一个源"都有的歌
pairs = []
for title, d in groups.items():
    if "jianpucn" in d and len(d) >= 2:
        for src, f in d.items():
            if src != "jianpucn":
                pairs.append((title, src, d["jianpucn"], f))

print(f"找到 {len(pairs)} 组「同一首歌、两个源」的配对\n")
print(f"{'歌名':<26}{'源':<10}{'老源(jianpucn)':>26}{'新源':>26}")
print("-" * 92)
shown = 0
for title, src, f_old, f_new in pairs:
    so, sn = stats(f_old), stats(f_new)
    if not so or not sn:
        continue
    print(f"{title[:24]:<26}{src:<10}"
          f"{so['n']:>6}音 x{so['x']*100:4.0f}% ?{so['q']*100:3.0f}%"
          f"{sn['n']:>10}音 x{sn['x']*100:4.0f}% ?{sn['q']*100:3.0f}%")
    shown += 1
    if shown >= 18:
        break

# 总体
if pairs:
    agg = collections.defaultdict(lambda: [0, 0.0, 0.0, 0])
    for title, src, f_old, f_new in pairs:
        for tag, f in (("老源 jianpucn", f_old), (src, f_new)):
            s = stats(f)
            if not s:
                continue
            a = agg[tag]
            a[0] += 1; a[1] += s["x"]; a[2] += s["q"]; a[3] += s["n"]
    print("\n=== 平均 ===")
    for tag, (cnt, x, q, n) in sorted(agg.items()):
        print(f"  {tag:<16} {cnt:3d} 首  平均 {n/cnt:6.1f} token  "
              f"x {100*x/cnt:4.1f}%  ? {100*q/cnt:4.1f}%")
