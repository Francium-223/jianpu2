# -*- coding: utf-8 -*-
"""裁一块放大, 用来看清低音点(数字下面的小点)。"""
import os, sys
from PIL import Image
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
src, dst = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = (int(v) for v in sys.argv[3:7])
scale = float(sys.argv[7]) if len(sys.argv) > 7 else 4.0
im = Image.open(src).convert("RGB").crop((x0, y0, x1, y1))
im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
im.save(dst, "PNG")
print("裁剪", (x0, y0, x1, y1), "->", im.size, dst)
