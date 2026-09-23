# -*- coding: utf-8 -*-
"""把某个转写结果(batch-out/<名>.png, 本身就是带框标注图)的**开头若干行**裁出来, 便于人眼核对。

用法: py -3.13 tools/crop_result.py "<batch-out 名(不含后缀)>" <输出png> [比例=0.22]
"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image

name = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "train-work/_crop.png"
frac = float(sys.argv[3]) if len(sys.argv) > 3 else 0.22
src = f"batch-out/{name}.png"
if not os.path.exists(src):
    sys.exit(f"没有 {src}")
im = Image.open(src).convert("RGB")
w, h = im.size
crop = im.crop((0, 0, w, max(1, int(h * frac))))
if crop.width > 1500:
    crop = crop.resize((1500, int(crop.height * 1500 / crop.width)), Image.LANCZOS)
crop.save(out)
print(f"{src} {im.size} -> {out} {crop.size}")
