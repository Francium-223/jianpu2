# -*- coding: utf-8 -*-
"""band9: 对照 真'-'杠 与 '2'数字 与 '5 6'下划线 的 y 位置。
打印各连通域 y(带内坐标), 验证 杠的y 与 下划线y 不同。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[9]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
print("band9 y[%d,%d] H=%d bar_extent=%s"%(s,e,e-s+1,be))
print("带内连通域(横线/数字/点), 按x排序:")
comps2=sorted(comps,key=lambda c:c[0])
for c in comps2:
    x0,y0,x1,y1,w,h=c[:6]
    if w<5 or w>60 or h>40: continue
    kind="?"; 
    if w>=2*h and w>=8: kind="横线"
    elif 8<=w<=22 and 14<=h<=34 and h>=w: kind="数字"
    elif 3<=w<=14 and 3<=h<=14: kind="点"
    print(f"  x[{x0}-{x1}] y[{y0}-{y1}] w={w} h={h} {kind}")
