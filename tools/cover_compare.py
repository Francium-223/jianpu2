# -*- coding: utf-8 -*-
"""严格验证封面底部那行到底是什么。

做法: 裁出顶部大字(已知是 TOHO EUROBEAT)与底部那行, 把底部做各种变换,
      再和顶部**并排拼在一张图里**对照。肉眼一比就知道是不是同一行字的翻转。
"""
import os
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")
SRC = r"C:\Users\qinxi\AppData\Roaming\dsh-desktop\harness\attachments\v1\objects\d6\d66854fdf876dce690a1c44337e39c3f63654b86442c362b52fe6553355e1c56"
OUT = r"D:\Documents_D\jianpu2\train-work\cover"
os.makedirs(OUT, exist_ok=True)

im = Image.open(SRC).convert("RGB")
W, H = im.size
print("原图:", (W, H))

# 顶部大字与底部那行(按比例估位, 留足余量)
top = im.crop((0, int(H * 0.03), W, int(H * 0.15)))
bot = im.crop((0, int(H * 0.87), W, int(H * 0.99)))
print("top:", top.size, " bottom:", bot.size)


def labeled(img, text):
    canvas = Image.new("RGB", (img.width, img.height + 34), (20, 20, 20))
    canvas.paste(img, (0, 34))
    ImageDraw.Draw(canvas).text((8, 8), text, fill=(255, 255, 0))
    return canvas


rows = [
    labeled(top, "TOP (known: TOHO EUROBEAT)"),
    labeled(bot, "BOTTOM as-is"),
    labeled(bot.transpose(Image.ROTATE_180), "BOTTOM rotate180"),
    labeled(bot.transpose(Image.FLIP_TOP_BOTTOM), "BOTTOM flip-vertical"),
    labeled(bot.transpose(Image.FLIP_LEFT_RIGHT), "BOTTOM flip-horizontal"),
]
maxw = max(r.width for r in rows)
total = sum(r.height for r in rows) + 10 * (len(rows) - 1)
sheet = Image.new("RGB", (maxw, total), (20, 20, 20))
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.height + 10
sheet = sheet.resize((int(maxw * 1.6), int(total * 1.6)), Image.LANCZOS)
p = os.path.join(OUT, "compare.png")
sheet.save(p)
print("导出:", p, sheet.size)
