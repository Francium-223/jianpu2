# -*- coding: utf-8 -*-
"""存 y127 行里被认成 '0' 的块的 crop 放大图, 看它们是什么."""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import numpy as np
from PIL import Image
import transcribe as T, transcribe_qwen as Q
import jp_transcribe as JP

IMG = "train-work/gt/兄弟抱一下.jpg"
arr = np.asarray(Image.open(IMG).convert("L")); content = arr < T.TOL
rows = [(s, e) for s, e in T.fine_rows(content, T.ROW_GAP) if T.count_bars(content[s:e+1], e-s+1) >= T.BAR_THR]
s, e = rows[0]
sub = content[s:e+1]; be = Q.bar_extent(sub)
crops = []
for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
    crop = Q.bound_to_note_row(arr[s:e+1], nx0, nx1, ny0, ny1, be)
    if crop is None or crop.size == 0: continue
    from classify_block import classify_block
    bt = classify_block(crop)
    crops.append((nx0, nx1, ny0, ny1, bt, crop))
print("第1行块数", len(crops))
# 存所有块的 crop (8x放大) 拼图
imgs = []
for nx0, nx1, ny0, ny1, bt, c in crops[:40]:
    im = Image.fromarray(c).convert("RGB")
    im = im.resize((im.width*4, im.height*4), Image.NEAREST)
    imgs.append((bt, im))
W = sum(i.width+8 for _, i in imgs); H = max(i.height for _, i in imgs)
out = Image.new("RGB", (min(W, 4000), (H+20)*3), "white")
x = y = 0
from PIL import ImageDraw
dr = ImageDraw.Draw(out)
for bt, i in imgs:
    if x + i.width > 4000: x = 0; y += H+20
    out.paste(i, (x, y)); dr.text((x+2, y+i.height+2), bt, fill=(255,0,0))
    x += i.width+8
out.save("train-work/xb_row1_crops.png")
print("saved train-work/xb_row1_crops.png", out.size, "bt种类:", {b: sum(1 for x,_,_,_,bb,_ in crops if bb==b) for b in set(bb for *_,bb,_ in crops)})
