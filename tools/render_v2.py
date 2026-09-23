# -*- coding: utf-8 -*-
"""渲染 = 复用 pipeline.transcribe 的同一套算法, 画每个块的框+token.
保证 图 == 转写. 用法: py tools/render_v2.py <img> <out.png>
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pipeline as P
from PIL import Image, ImageDraw, ImageFont
IMG, OUT = sys.argv[1], sys.argv[2]
toks, meta = P.transcribe(IMG)
img = Image.open(IMG).convert("RGB")
dr = ImageDraw.Draw(img); font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 9)
cm = {"digit": (0, 90, 255), "digit_rejected": (200, 0, 0), "dash": (150, 150, 150), "rest": (0, 150, 0)}
W, H = img.size
for b in meta:
    cx0 = max(0, b["x0"] - 8); cx1 = min(W - 1, b["x1"] + 8)
    cy0 = max(0, b["s"] + b["ny0"] - 8); cy1 = min(H - 1, b["s"] + b["y1"] + 8)
    col = cm.get(b["btype"], (0, 90, 255))
    dr.rectangle([cx0, cy0, cx1, cy1], outline=col, width=1)
    if b["tok"]: dr.text((cx0 + 1, cy0 + 1), b["tok"], fill=col, font=font)
img.save(OUT); print("saved", OUT, "音", len(toks))
