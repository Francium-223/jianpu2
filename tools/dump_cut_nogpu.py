# -*- coding: utf-8 -*-
"""把问候歌"切开"的每个块拼成一张图(纯几何, 不加载模型, 不占 GPU)。

流程与 jp_transcribe 一致: 行带过滤 -> crop_note_regions -> bound_to_note_row,
只是不做模型识别, 便于核对"切得对不对"。
"""
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
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
H, W = arr.shape
print(f"图 {W}x{H}")

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

cells = []          # (band, x0,y0,x1,y1, crop, btype)
n_bands_kept = 0
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    if frac < 0.85:
        print(f"  行带 y[{s},{e}] frac={frac:.2f} -> 丢弃")
        continue
    n_bands_kept += 1
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    regs = T.crop_note_regions(sub)
    print(f"  行带 y[{s},{e}] h={e-s+1} frac={frac:.2f} 切出 {len(regs)} 块")
    for (nx0, nx1, ny0, ny1) in regs:
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        cells.append((s, nx0, ny0, nx1, ny1, crop, classify_block(crop)))

print(f"\n保留行带 {n_bands_kept} 个, 共 {len(cells)} 块")
from collections import Counter
print("btype 分布:", dict(Counter(c[6] for c in cells)))

# 拼图: 每块一格, 标 btype
CELL, PAD = 90, 6
cols = 16
rows = (len(cells) + cols - 1) // cols
canvas = Image.new("L", (cols * (CELL + PAD) + PAD, rows * (CELL + 20) + PAD), 255)
d = ImageDraw.Draw(canvas)
for i, (s, nx0, ny0, nx1, ny1, crop, bt) in enumerate(cells):
    r, c = divmod(i, cols)
    px = PAD + c * (CELL + PAD); py = PAD + r * (CELL + 20)
    im = Image.fromarray(crop)
    w, h = im.size
    sc = min(CELL / max(w, 1), CELL / max(h, 1), 4.0)
    im = im.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    canvas.paste(im, (px + (CELL - im.size[0]) // 2, py + (CELL - im.size[1]) // 2))
    d.text((px, py + CELL + 2), f"{i}:{bt[:5]}", fill=0)
canvas.save("train-work/问候歌_切开.png")
print("\n已存: train-work/问候歌_切开.png")
