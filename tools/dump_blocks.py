# -*- coding: utf-8 -*-
"""把识别出的每个块裁出来拼成图(标注 token), 用于核对"0"是真休止还是空块幻觉。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image, ImageDraw
import jp_transcribe as JP
import transcribe as T

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
toks, meta = JP.render(page, "train-work/_tmp.png")
arr = np.asarray(Image.open(page).convert("L"))
H, W = arr.shape
print(f"图 {W}x{H}  token {len(toks)}")

CELL, PAD = 96, 8
cols = 11
canvas = Image.new("L", (cols * (CELL + PAD) + PAD, 4 * (CELL + 22) + PAD), 255)
d = ImageDraw.Draw(canvas)

for i, (t, m) in enumerate(zip(toks, meta)):
    y0 = max(0, m["band"] + m["ny0"] - 8)
    y1 = min(H, m["band"] + m["y1"] + 10)
    x0 = max(0, m["x0"] - 6); x1 = min(W, m["x1"] + 6)
    patch = arr[y0:y1, x0:x1]
    n_ink = int((patch < T.TOL).sum())
    n_px = max(patch.size, 1)
    # 块内最大连通域尺寸
    comps = T.components(patch < T.TOL) if patch.size else []
    big = max((c[5] for c in comps), default=0)
    wide = max((c[4] for c in comps), default=0)
    r, c = divmod(i, cols)
    px = PAD + c * (CELL + PAD); py = PAD + r * (CELL + 22)
    im = Image.fromarray(patch)
    w, h = im.size
    sc = min(CELL / max(w, 1), CELL / max(h, 1), 3.0)
    im = im.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    canvas.paste(im, (px + (CELL - im.size[0]) // 2, py + (CELL - im.size[1]) // 2))
    d.text((px, py + CELL + 2), f"[{i}]{t}", fill=0)
    d.text((px, py + CELL + 11), f"墨{n_ink*100//n_px}% w{wide} h{big}", fill=0)
    print(f"[{i:2d}] tok={t:5s} 墨迹占比={n_ink*100/n_px:5.1f}%  最大连通域 w={wide:3d} h={big:3d}  crop={patch.shape}")

canvas.save("train-work/问候歌_块.png")
print("\n已存: train-work/问候歌_块.png")
