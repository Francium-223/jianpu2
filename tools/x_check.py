# -*- coding: utf-8 -*-
"""把识别为 'x' 的块裁出来拼成网格图, 供人眼判断是真念白还是误判。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import jp_transcribe as JP

sheet_dir = sys.argv[1] if len(sys.argv) > 1 else "images-prep/qupu123-crawl/将进酒__qupu123-382162"
out = sys.argv[2] if len(sys.argv) > 2 else "train-work/xcheck.png"
imgs = sorted(glob.glob(os.path.join(sheet_dir, "*.jpg")), key=os.path.getsize)
src = imgs[-1]
print("谱:", src)

toks, meta = JP.render(src, "train-work/_tmp_full.png")
print(f"总 token {len(toks)}, 其中 x = {sum(1 for t in toks if 'x' in t)}")

arr = np.asarray(Image.open(src).convert("L"))
H, W = arr.shape

# 收集 x 块与"非x"块各若干, 并排对比
xs, others = [], []
for t, m in zip(toks, meta):
    y0 = max(0, m["band"] + m["ny0"] - 10)
    y1 = min(H, m["band"] + m["y1"] + 12)
    x0 = max(0, m["x0"] - 8); x1 = min(W, m["x1"] + 8)
    if y1 - y0 < 8 or x1 - x0 < 6:
        continue
    patch = arr[y0:y1, x0:x1]
    (xs if "x" in t else others).append((t, patch))

print(f"裁到 x 块 {len(xs)} 个, 对照块 {len(others)} 个")

def grid(items, cols=12, cell=90, pad=6):
    if not items:
        return None
    rows = (len(items) + cols - 1) // cols
    from PIL import ImageDraw
    canvas = Image.new("L", (cols * (cell + pad) + pad, rows * (cell + 20) + pad), 255)
    d = ImageDraw.Draw(canvas)
    for i, (t, p) in enumerate(items):
        r, c = divmod(i, cols)
        px = pad + c * (cell + pad); py = pad + r * (cell + 20)
        im = Image.fromarray(p)
        w, h = im.size
        sc = min(cell / max(w, 1), cell / max(h, 1), 3.0)
        im = im.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
        canvas.paste(im, (px + (cell - im.size[0]) // 2, py + (cell - im.size[1]) // 2))
        d.text((px, py + cell + 2), t[:10], fill=0)
    return canvas

g1 = grid(xs[:60], cols=10, cell=80)
g2 = grid(others[:60], cols=10, cell=80)
if g1:
    g1.save(out)
    print("已存:", out)
if g2:
    p2 = out.replace(".png", "_others.png")
    g2.save(p2)
    print("已存:", p2)
