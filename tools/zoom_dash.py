# -*- coding: utf-8 -*-
"""看位置73(带7 x583) 与 91(带9 x448) 的裁剪——GT 说是 '-'(延音杠), 但输出 0/5。
放大这两个位置, 看是真'-'还是被误切/误判。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image
im=Image.open("images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg")
# 带7 y[603,649] x550-600 附近 '5 -' 的 - ; 带9 y[734,779] x420-480 '5 -' 的 -
im.crop((540,600,620,660)).resize((400,300),Image.LANCZOS).save("train-work/zoom_dash7.png")
im.crop((420,732,480,782)).resize((360,250),Image.LANCZOS).save("train-work/zoom_dash9.png")
print("ok")
