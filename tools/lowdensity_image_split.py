# -*- coding: utf-8 -*-
"""把低密度守卫命中的那批按"原图到底是不是谱页"再切一刀。

为什么: 看图时发现有些行的"原图"是同一张 750x55 的网站横幅（sha 一致），
那不是谱页。这类行的 `页数` 是假的，失败原因也不是"模型读不动屏幕上的谱"。
判据（粗但够用）: 原图目录里**最大的那个文件** < 30 KB -> 只可能是横幅/碎片图，不是谱页扫描。
"""
import glob
import io
import os
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
CENSUS = os.path.join(ROOT, "_analysis", "lowdensity_census.tsv")

rows = []
for line in io.open(CENSUS, encoding="utf-8"):
    if line.startswith("#") or not line.strip():
        continue
    p = line.rstrip("\n").split("\t")
    if len(p) < 6:
        continue
    rows.append(dict(ratio=float(p[0]), notes=int(p[1]), pages=int(p[2]),
                     title=p[3], stem=p[4], src=p[5]))
hit = [r for r in rows if r["ratio"] < 15 and r["pages"] >= 2]

banner, real, noimg = [], [], []
for r in hit:
    d = glob.glob(os.path.join("images-prep", "**", r["stem"] + "__" + r["src"]), recursive=True)
    if not d:
        noimg.append(r)
        continue
    fs = [f for f in glob.glob(os.path.join(d[0], "*")) if os.path.isfile(f)]
    mx = max((os.path.getsize(f) for f in fs), default=0)
    (banner if mx < 30_000 else real).append(r)

print("命中 %d 份，按原图切：" % len(hit))
print("  最大文件 <30KB（横幅/碎片，不是谱页）: %d 份" % len(banner))
print("  有像样的谱页扫描件:                  %d 份" % len(real))
print("  本地找不到原图目录:                  %d 份" % len(noimg))
print()
print("  「有谱页扫描」那批里最极端的 6 份（这批才是“输入好、模型失败”）:")
for r in sorted(real, key=lambda x: x["ratio"])[:6]:
    print("    %5.1f 音/页 · %3d 音 / %2d 页 · %s [%s]"
          % (r["ratio"], r["notes"], r["pages"], r["title"][:20], r["src"]))
print()
print("  「横幅/碎片」那批的来源分布:", dict(Counter(r["src"].split("-")[0] for r in banner)))
print("  「有谱页扫描」那批的来源分布:", dict(Counter(r["src"].split("-")[0] for r in real)))
