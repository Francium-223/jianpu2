# -*- coding: utf-8 -*-
"""验证专辑封面底部那行"像卢恩文"的字其实是镜像的拉丁字母。
裁出底部条带, 做 4 种变换, 看哪一种能读成正常英文。
"""
import os
import sys
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
SRC = r"C:\Users\qinxi\AppData\Roaming\dsh-desktop\harness\attachments\v1\objects\d6\d66854fdf876dce690a1c44337e39c3f63654b86442c362b52fe6553355e1c56"
os.makedirs(r"D:\Documents_D\jianpu2\train-work\cover", exist_ok=True)
OUT = r"D:\Documents_D\jianpu2\train-work\cover"

im = Image.open(SRC).convert("RGB")
print("原图:", im.size)
W, H = im.size
# 底部条带(镜像文字所在)
strip = im.crop((0, int(H * 0.86), W, H))
strip = strip.resize((strip.width * 2, strip.height * 2), Image.LANCZOS)
strip.save(os.path.join(OUT, "0_原始.png"))

strip.transpose(Image.ROTATE_180).save(os.path.join(OUT, "1_旋转180.png"))
strip.transpose(Image.FLIP_TOP_BOTTOM).save(os.path.join(OUT, "2_上下翻转.png"))
strip.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, "3_左右翻转.png"))
print("已导出 4 个变体到", OUT)
