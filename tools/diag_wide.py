# -*- coding: utf-8 -*-
"""查: 那些"宽 region"(两个数字连体)从哪来 —— dashes 还是 digits。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    if frac < 0.85:
        continue
    print(f"\n=== 行带 y[{s},{e}] ===")
    # 重现 crop_note_regions 内部: 切分后的 comps
    comps = T.components(st)
    _ws = sorted(c[4] for c in comps if 12 <= c[5] <= 45)
    med = _ws[len(_ws) // 2] if _ws else 10
    print(f"  数字宽中位={med}  1.8x={1.8*med:.1f}")
    wide = [c for c in comps if c[4] > 1.8 * med and c[5] >= 12]
    print(f"  宽连通域(应被切): {len(wide)} 个")
    for c in wide[:6]:
        print(f"    x[{c[0]},{c[2]}] y[{c[1]},{c[3]}] w={c[4]} h={c[5]}")
    regs = T.crop_note_regions(sub)
    wide_regs = [(a, b, c2, d2) for (a, b, c2, d2) in regs if (b - a + 1) > (d2 - c2 + 1)]
    print(f"  切出的 region: {len(regs)} 个, 其中宽region(宽>高): {len(wide_regs)} 个")
    for r in wide_regs[:6]:
        print(f"    x[{r[0]},{r[1]}] y[{r[2]},{r[3]}] w={r[1]-r[0]+1} h={r[3]-r[2]+1}")
    break
