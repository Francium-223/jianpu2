# -*- coding: utf-8 -*-
"""CPU 验证"带内 y 分簇"能否把谱头块挑出来(不加载模型, 用几何类型判 digit)。

对若干已知有谱头泄漏的谱, 打印: 前两个行带里, 基线以上的块被丢掉多少、
留下的块数、以及这些块几何类型分布。
"""
import glob
import os
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

NAMES = [
    "10信念（双谱）__qupu123-319833",
    "35月光（双谱）__qupu123-316904",
    "40高山流水（双谱）__qupu123-320184",
]

for NAME in NAMES:
    d = next((x for x in glob.glob("images-prep/*/*")
              if os.path.isdir(x) and BT.safe_name(os.path.basename(x)) == NAME), None)
    if not d:
        print(f"{NAME}: 找不到目录"); continue
    p = BT.pick_page(d)
    im = Image.open(p).convert("L")
    if im.width > 2000:
        im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
    elif im.width < 950:
        im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
    g = np.asarray(im) < T.TOL
    print(f"\n=== {NAME} ===")
    bands = list(T.fine_rows(g, T.ROW_GAP))[:2]
    for bi, (s, e) in enumerate(bands):
        sub = g[s:e + 1]
        regs = T.crop_note_regions(sub)
        # 几何判类型(简化: 瘦高块算 digit)
        st, hl = T.strip_hlines(sub)
        cs = [x for x in T.components(st) if 12 <= x[5] <= 45 and x[4] >= 3]
        tall = [x for x in cs if x[5] >= 1.15 * x[4]]
        # 连通域元组是 (x0, y0, x1, y1, w, h) —— y 是 [1] 和 [3]
        ys = sorted((r[1] + r[3]) / 2.0 for r in tall)
        if not ys:
            print(f"  带{bi} y={s}-{e}: 没有瘦高块"); continue
        med = ys[len(ys) // 2]
        up = [y for y in ys if y < med - 26]
        print(f"  带{bi} y={s}-{e} 高{e-s+1}: 块{len(regs)} 瘦高{len(tall)} "
              f"y范围[{ys[0]:.0f},{ys[-1]:.0f}] 中位{med:.0f} "
              f"-> 基线以上 {len(up)} 个将被丢")
