# -*- coding: utf-8 -*-
"""把伪装扩展名的图转成真 PNG 方便我读。"""
import os, sys
from PIL import Image
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
src = sys.argv[1]
dst = sys.argv[2]
im = Image.open(src)
print("真实格式:", im.format, im.size, im.mode)
im.convert("RGB").save(dst, "PNG")
print("已写出:", dst, os.path.getsize(dst))
