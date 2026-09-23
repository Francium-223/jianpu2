# -*- coding: utf-8 -*-
"""dump 兄弟抱一下 的所有块(行/坐标/token) + 画框叠加图, 查多切的是什么."""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
from PIL import Image, ImageDraw, ImageFont
import jp_transcribe as JP

IMG = "train-work/gt/兄弟抱一下.jpg"
toks, meta = JP.transcribe(IMG)
print("总块", len(meta), "总音", len(toks), flush=True)
# 按行统计
from collections import defaultdict
rows = defaultdict(list)
for b in meta:
    rows[b["band"]].append(b)
for band in sorted(rows):
    bs = rows[band]
    ts = " ".join(x["tok"] for x in bs)
    print(f"行y{band}: {len(bs)}块: {ts[:110]}", flush=True)
# 画框
im = Image.open(IMG).convert("RGB"); dr = ImageDraw.Draw(im)
try: font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 9)
except Exception: font = ImageFont.load_default()
for b in meta:
    col = (0, 90, 255)
    if b["btype"] == "dash": col = (150, 150, 150)
    elif b["btype"] == "rest": col = (0, 150, 0)
    dr.rectangle([b["x0"]-4, b["s"]+b["ny0"]-4, b["x1"]+4, b["s"]+b["y1"]+4], outline=col, width=1)
    dr.text((b["x0"]-3, b["s"]+b["ny0"]-3), b["tok"], fill=col, font=font)
im.save("train-work/xb_blocks.png")
print("saved train-work/xb_blocks.png", flush=True)
