# -*- coding: utf-8 -*-
"""给《你怎么说（补临时声部）》(jianpucn-451637) 的原谱画标注图: 圈出语料里 `33565653253` 落在哪一带。

定位依据(实测, 不是估的):
  * 语料 `你怎么说_2.txt` 里这串是**第 83–93 个音**(token `3' 3 s5 s6 q5 s6 s5 q3 q2 q5' q3'`);
  * 全页转写是**按行从上到下**出 token 的, 但**不存坐标** -> 用 `_analysis/locate_phrase.py` 把图
    逐行切出来重新认一遍: 第 3 音乐行右边那个番奏括号认出来就是 `5656532`, 与这串的后 7 个音
    `5 6 5 6 5 3 2` **逐个相同**; 前两个 `3 3` 是这一行**行尾的 `3 -`**; 末尾 `5 3` 是下一行的开头。
  * 也就是说: 语料里那 11 个音横跨"第 1 段唱词行的行尾 + 紧跟的间奏括号"。

只读原图; 输出标注图到 train-work/。用法: py -3.13 _analysis/annotate_phrase.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

IMG = r"images-prep\jianpucn-denglijun\你怎么说（补临时声部）__jianpucn-451637\001.jpg"
OUT = r"train-work\你怎么说_33565653253_标注.png"
FONT = r"C:\Windows\Fonts\msyh.ttc"

# 圈选区域(像素; 原图 2480x3508) —— 行尾的 `3 -` + 间奏括号 `(5 6 | 5 65 3 2`
BOX = (1520, 1240, 2465, 1352)
ZOOM_SCALE = 1.6


def main():
    src = Image.open(IMG).convert("RGB")
    # **在下面接一条白边**放说明文字与放大图 —— 免得压住谱面(用户要的是"一眼看清", 不是叠字)
    BAND = 470
    im = Image.new("RGB", (src.width, src.height + BAND), (255, 255, 255))
    im.paste(src, (0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    x0, y0, x1, y1 = BOX
    d.rounded_rectangle([x0, y0, x1, y1], radius=18, fill=(220, 30, 30, 46),
                        outline=(200, 20, 20, 255), width=8)
    d.line([(x0, (y0 + y1) // 2), (x0 - 140, (y0 + y1) // 2)], fill=(200, 20, 20, 255), width=6)
    f = ImageFont.truetype(FONT, 54)
    fs = ImageFont.truetype(FONT, 40)
    tx, ty = 120, src.height + 26
    d.text((tx, ty), "语料里的 33565653253 落在红框这一带", font=f, fill=(180, 15, 15))
    d.text((tx, ty + 68), "红框里印的是间奏括号 (5 6 | 5 65 3 2 —— 它的 7 个音 5 6 5 6 5 3 2", font=fs,
           fill=(70, 70, 70))
    d.text((tx, ty + 114), "与语料那串的后 7 个音逐个相同；前面两个 3 来自上一行行尾的 3 -。", font=fs,
           fill=(70, 70, 70))
    d.text((tx, ty + 160), "注: 整页转写只存 token 顺序、不存坐标, 这里是**逐行重认一遍**定位出来的。", font=fs,
           fill=(130, 130, 130))

    crop = src.crop(BOX)
    zw, zh = int(crop.width * 1.15), int(crop.height * 1.15)
    crop = crop.resize((zw, zh), Image.LANCZOS)
    pad = 12
    inset = Image.new("RGB", (zw + pad * 2, zh + pad * 2), (255, 255, 255))
    inset.paste(crop, (pad, pad))
    di = ImageDraw.Draw(inset)
    di.rectangle([0, 0, inset.width - 1, inset.height - 1], outline=(200, 20, 20), width=6)
    im.paste(inset, (tx, ty + 220))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    print("写出", OUT, im.size)
    big = src.crop(BOX)
    big = big.resize((int(big.width * 1.9), int(big.height * 1.9)), Image.LANCZOS)
    big.save(r"train-work\你怎么说_33565653253_放大.png")
    print("写出 train-work\\你怎么说_33565653253_放大.png", big.size)


if __name__ == "__main__":
    main()
