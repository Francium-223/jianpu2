# -*- coding: utf-8 -*-
"""对照实验: 有"谱头泄漏"的谱 vs 没有的, 第一行带的几何特征差在哪。

分组依据: 转写开头是否有成片的 '-'+'x'(即 scan_header_leak 的判据)。
测量每个谱**第一个被接受的行带**的: frac / nline / 最长下划线长度 / 瘦高块数。
纯 CPU, 不加载模型。
"""
import glob
import io
import os
import random
import re
import statistics
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

N = int(sys.argv[1]) if len(sys.argv) > 1 else 60


def has_leak(path):
    toks = io.open(path, encoding="utf-8", errors="replace").read().split()[:14]
    return sum(1 for t in toks if t == "-") >= 3 and sum(1 for t in toks if t == "x") >= 1


files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f)[:-4] not in ("progress", "skipped")]
leak = [f for f in files if has_leak(f)]
clean = [f for f in files if f not in set(leak)]
print(f"语料 {len(files)}: 有泄漏 {len(leak)}, 无泄漏 {len(clean)}")
random.seed(1)
random.shuffle(leak); random.shuffle(clean)
leak, clean = leak[:N], clean[:N]


def first_band_feat(f):
    name = os.path.basename(f)[:-4]
    d = next((x for x in glob.glob("images-prep/*/*")
              if os.path.isdir(x) and BT.safe_name(os.path.basename(x)) == name), None)
    if not d:
        return None
    try:
        p = BT.pick_page(d)
        im = Image.open(p).convert("L")
        if im.width > 2000:
            im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
        elif im.width < 950:
            im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
        g = np.asarray(im) < T.TOL
        for s, e in list(T.fine_rows(g, T.ROW_GAP))[:3]:     # 只看最前面几个带
            sub = g[s:e + 1]
            st, hl = T.strip_hlines(sub)
            cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
            if not cs:
                continue
            tall = [c for c in cs if c[5] >= 1.15 * c[4]]
            frac = len(tall) / len(cs)
            nline = sum(1 for h in hl if h[4] >= 8)
            maxline = max((h[4] for h in hl), default=0)
            if frac >= 0.85 or (len(tall) >= 6 and nline >= 1):
                return dict(frac=frac, nline=nline, maxline=maxline, tall=len(tall))
        return None
    except Exception:
        return None


def summarize(label, fs):
    rows = [r for r in (first_band_feat(f) for f in fs) if r]
    if not rows:
        print(f"{label}: 无数据"); return
    print(f"\n{label}  (n={len(rows)})")
    for k in ("frac", "nline", "maxline", "tall"):
        v = [r[k] for r in rows]
        print(f"   {k:8s} 中位 {statistics.median(v):7.2f}   "
              f"均值 {statistics.mean(v):7.2f}   范围 [{min(v):.0f},{max(v):.0f}]")


summarize("A) 有谱头泄漏的谱", leak)
summarize("B) 无泄漏的谱", clean)
