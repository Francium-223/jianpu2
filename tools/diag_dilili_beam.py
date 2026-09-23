# -*- coding: utf-8 -*-
"""看 band7 最后 '1 1 1 1 2' 的下划线几何: 每个块底部暗像素行分布 + 下划线行数/粗细。
判断 geo_detect 是否漏判细/双下划线。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[7]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    w=nx1-nx0; h=y1-ny0
    if w>20 or h<10 or ny0>be[1]: continue
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    m=crop<170; Hh,Ww=m.shape
    # 底部各行暗像素数(下划线行)
    bot=[]
    for yy in range(max(0,Hh-14),Hh):
        bot.append(int(m[yy].sum()))
    # 找数字主体高度(顶到暗的底部)
    rows=m.sum(axis=1); ny=[i for i,v in enumerate(rows) if v>0]
    digit_bottom=max(ny) if ny else -1
    print(f"x[{nx0}-{nx1}] w={w} h={Hh} 数字底y={digit_bottom} 底14行暗px={bot}")
