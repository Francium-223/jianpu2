# -*- coding: utf-8 -*-
"""在原图上画出所有切出的块(纯几何, 不加载模型, 不占 GPU)。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image, ImageDraw
import transcribe as T
import transcribe_qwen as Q
from classify_block import classify_block

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
g = Image.open(page).convert("RGB")
arr = np.asarray(g.convert("L"))
content = arr < T.TOL
d = ImageDraw.Draw(g)

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

kept = 0
n_box = 0
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    if frac < 0.85:
        # 被丢弃的行: 画灰框示意
        d.rectangle([2, s, g.size[0] - 3, e], outline=(200, 200, 200), width=1)
        continue
    kept += 1
    be = Q.bar_extent(sub)
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        crop = Q.bound_to_note_row(arr[s:e + 1], nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        bt = classify_block(crop)
        col = (0, 160, 0) if bt == "digit" else ((0, 0, 220) if bt == "dash" else (220, 0, 0))
        d.rectangle([nx0, s + ny0, nx1, s + ny1], outline=col, width=2)
        n_box += 1

g.save("train-work/问候歌_切分.png")
print(f"保留音符行 {kept} 个, 画框 {n_box} 个")
print("已存: train-work/问候歌_切分.png  (绿=数字, 蓝=延音杠, 红=其它, 灰=被丢弃的行)")
