# -*- coding: utf-8 -*-
"""诊断: 为什么这张五线谱 nline=0。看行剖面(最长连续暗段 / 横向覆盖率)。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

d = "丁小琴编-19打起手鼓唱起歌（正谱）__qupu123-325175"
g0 = glob.glob("images-prep/*/" + glob.escape(d))
p = BT.pick_page(g0[0])
im = Image.open(p).convert("L")
print(f"图 {im.size}")
g = np.asarray(im).astype(np.int16)
print(f"灰度: 均值 {g.mean():.1f}  最小 {g.min()}  最大 {g.max()}")
for thr in (100, 128, 160, 180, 200, 210, 220, 230):
    c = g < thr
    W = c.shape[1]
    rs = c.sum(axis=1)
    # 最长连续段
    best = 0
    n_long = 0
    n_wide = int((rs > 0.60 * W).sum())
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        dd = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(dd == 1)[0]
        en = np.where(dd == -1)[0]
        L = int((en - st).max())
        best = max(best, L)
        if L >= 0.55 * W:
            n_long += 1
    print(f"  thr={thr:3d}: 墨 {100*c.mean():5.1f}%  最长段 {best:4d}px ({100*best/W:5.1f}%页宽)  "
          f"长段行 {n_long:3d}  覆盖>60% 行 {n_wide:3d}")
