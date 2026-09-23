# -*- coding: utf-8 -*-
"""对比 x452的3(判成0) vs 前面正确的3(块2 x114)。放大两张裁剪。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L"))
# x452的3: 裁 x[448,468] y[118,172]
im=Image.open(F)
a=im.crop((445,110,475,180)).resize((300,700),Image.LANCZOS)
b=im.crop((108,110,138,180)).resize((300,700),Image.LANCZOS)
c=Image.new("RGB",(620,700),(255,255,255)); c.paste(a,(0,0)); c.paste(b,(320,0))
c.save("train-work/zoom_3_compare.png")
print("ok: 左=x452的3(判0) 右=前面正确的3(判3)")
