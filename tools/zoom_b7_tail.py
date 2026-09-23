# -*- coding: utf-8 -*-
"""放大 带7 末尾 (x560-700) 的 '5 - | 11 11 2', 看 延音杠 - 与 1 的块, 为何 - 被误判成0, 1 时值为何乱。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image
im=Image.open("images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg")
# band7 = y[603,649], 末尾 x550-710 放歌词 '嘀哩哩嘀哩' 那行后段
im.crop((545,600,715,660)).resize((850,300),Image.LANCZOS).save("train-work/zoom_band7_tail.png")
print("ok")
