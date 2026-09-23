# -*- coding: utf-8 -*-
"""放大 band7 的 4 4 4 4 5 裁剪, 看 4 是否因低分辨率糊成 3/5 形状。
也放大对比一个 真3/真5 块。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
im=Image.open(F)
# band7 y595-660, 前段 4 4 4 4 5 (x10-150), 放大
im.crop((8,595,160,660)).resize((912,390),Image.LANCZOS).save('train-work/zoom_4s.png')
print('ok')
