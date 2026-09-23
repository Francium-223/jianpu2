# -*- coding: utf-8 -*-
"""各源转写质量对照。

两条路:
  A) 全库统计: 按来源分, 有效谱比例 / 平均 token / x率(歌词污染) / ?率(读不出)
  B) 同曲配对: 按**归一化标题**配对, 同一首歌在 jianpucn 与 qupu123/jianpujia 各转一次再比
"""
import collections
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f)[:-4] not in ("progress", "skipped")]
print(f"语料 {len(files)} 个\n")

# ---------- A) 按来源统计 ----------
agg = collections.defaultdict(lambda: dict(n=0, empty=0, tok=0, x=0, q=0, tot=0))
for f in files:
    b = os.path.basename(f)[:-4]
    m = re.search(r"__([a-z0-9.]+)-(\d+)$", b)
    src = m.group(1) if m else "(无源)"
    d = agg[src]
    toks = io.open(f, encoding="utf-8", errors="replace").read().split()
    d["n"] += 1
    d["tok"] += len(toks)
    d["tot"] += len(toks)
    if len(toks) == 0:
        d["empty"] += 1
    d["x"] += sum(1 for t in toks if t == "x")
    d["q"] += sum(1 for t in toks if t == "?")

print("=== A) 各源汇总(只看转出结果的谱) ===")
print(f"{'源':<12}{'谱数':>7}{'空结果':>8}{'平均token':>11}{'x率':>8}{'?率':>8}")
print("-" * 56)
for src, d in sorted(agg.items(), key=lambda x: -x[1]["n"]):
    n, tot = d["n"], max(d["tot"], 1)
    print(f"{src:<12}{n:>7}{d['empty']:>8}{d['tok']/n:>11.1f}"
          f"{100*d['x']/tot:>7.1f}%{100*d['q']/tot:>7.1f}%")

# ---------- B) 同曲配对 ----------
try:
    from to_jianpu_db import title_of
except Exception:
    title_of = lambda s: s

bytitle = collections.defaultdict(dict)
for f in files:
    b = os.path.basename(f)[:-4]
    m = re.search(r"__([a-z0-9.]+)-(\d+)$", b)
    if not m:
        continue
    t = title_of(b)
    if not t or t.startswith("未命名"):
        continue
    bytitle[t].setdefault(m.group(1), f)

pairs = [(t, d) for t, d in bytitle.items()
         if "jianpucn" in d and any(s != "jianpucn" for s in d)]
print(f"\n=== B) 同曲配对: {len(pairs)} 组 ===")
if pairs:
    print(f"{'歌名':<24}{'老源(jianpucn)':>22}{'新源':>24}")
    print("-" * 74)
    for t, d in pairs[:15]:
        f_old = d["jianpucn"]
        src_new = next(s for s in d if s != "jianpucn")
        f_new = d[src_new]
        def st(p):
            toks = io.open(p, encoding="utf-8", errors="replace").read().split()
            n = max(len(toks), 1)
            return f"{len(toks):>5}音 x{100*sum(1 for q in toks if q=='x')/n:3.0f}%"
        print(f"{t[:22]:<24}{st(f_old):>22}{st(f_new)+' ['+src_new+']':>24}")
