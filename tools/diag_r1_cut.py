# -*- coding: utf-8 -*-
"""检查 块11 x[452-463] 的裁剪是否把右邻 0 卷进来: 打印该块实际裁剪内容特征
(相邻暗像素连通性/右边界是否贴到0)。同时打印相邻 0(块12 x514)位置。"""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[1]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
print("bar_extent", be)
# 连通域x范围(候选数字)
for c in sorted(comps,key=lambda x:x[0]):
    x0,y0,x1,y1,w,h=c[:6]
    if w>22 or h>26 or w<5: continue
    if y0>be[1] or y1>be[1]+2: continue
    print(f"连通域 x[{x0}-{x1}] y[{y0}-{y1}] w={w} h={h}")
# 打印 x430-480 的暗像素列分布(看3与0之间空白)
print("\n列暗像素(带内y0..bar_bottom):")
for x in range(428,485,2):
    col=content[s+0:s+e+1, x]
    print(f"  x{x}: 暗px={int(sub[:,x].sum())}")
