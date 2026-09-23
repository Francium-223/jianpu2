# -*- coding: utf-8 -*-
"""诊断: 调号行与第一行音乐是不是被 fine_rows 并成了同一个行带?
纯几何(CPU), 不加载模型。
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

NAME = sys.argv[1] if len(sys.argv) > 1 else "10信念（双谱）__qupu123-319833"
d = None
for x in glob.glob("images-prep/*/*"):
    if os.path.isdir(x) and BT.safe_name(os.path.basename(x)) == NAME:
        d = x
        break
if not d:
    print("找不到", NAME); sys.exit(1)
p = BT.pick_page(d)
im = Image.open(p).convert("L")
if im.width > 2000:
    im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
elif im.width < 950:
    im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
g = np.asarray(im) < T.TOL
print(f"图 {im.size}, ROW_GAP={T.ROW_GAP}")
print(f"{'行带':>4} {'y范围':>12} {'高':>4} {'块数':>5}  说明")
for k, (s, e) in enumerate(T.fine_rows(g, T.ROW_GAP)):
    sub = g[s:e + 1]
    regs = T.crop_note_regions(sub)
    st, hl = T.strip_hlines(sub)
    cs = [x for x in T.components(st) if 12 <= x[5] <= 45 and x[4] >= 3]
    tall = [x for x in cs if x[5] >= 1.15 * x[4]]
    note = ""
    if k < 4:
        # 看这一带里各块的 y 分布: 若明显分两簇 -> 其实是两行被并了
        ys = sorted(r[2] for r in regs)
        if ys:
            gaps = [(ys[i + 1] - ys[i], ys[i], ys[i + 1]) for i in range(len(ys) - 1)]
            gmax = max(gaps) if gaps else (0, 0, 0)
            note = f"块y范围[{ys[0]},{ys[-1]}] 最大间隙{gmax[0]}"
    print(f"{k:>4} {s:>5}-{e:<5} {e-s+1:>4} {len(regs):>5}  瘦高块{len(tall):>3}  {note}")
    if k > 5:
        break
