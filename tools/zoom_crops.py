# -*- coding: utf-8 -*-
"""把几个 crop 放大 8 倍存图, 人工核对下划线是一条还是两条。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image, ImageDraw
import transcribe as T
import transcribe_qwen as Q

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
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    regs = T.crop_note_regions(sub)
    crops = []
    for (nx0, nx1, ny0, ny1) in regs:
        c = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if c is None or c.size == 0:
            continue
        crops.append(((nx0, nx1), c))
    print(f"行带 y[{s},{e}] 块={len(crops)}")
    # 拼前 10 个块, 放大 8 倍
    SC = 8
    CELL = 40 * SC
    canvas = Image.new("L", (min(len(crops), 10) * (CELL + 10) + 10, CELL + 40), 255)
    d = ImageDraw.Draw(canvas)
    for i, ((nx0, nx1), c) in enumerate(crops[:10]):
        im = Image.fromarray(c).resize((c.shape[1] * SC, c.shape[0] * SC), Image.NEAREST)
        px = 10 + i * (CELL + 10)
        canvas.paste(im, (px, 10))
        d.text((px, CELL + 15), f"x{nx0}-{nx1} {c.shape}", fill=0)
    canvas.save("train-work/问候歌_时值线.png")
    print("已存: train-work/问候歌_时值线.png")
    break
