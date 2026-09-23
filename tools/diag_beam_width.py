# -*- coding: utf-8 -*-
"""测量 band7 '11 11 2' 各块: 数字主体宽、下划线宽、下划线行数。
用于确定 beam(时值) 判定的安全几何阈值。"""
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
    # 逐连通域分析
    comps2=_components(crop<170)
    main=max(comps2,key=lambda c:c[5])
    mw=main[4]  # 数字主体宽
    mh=main[5]
    # 下划线候选: 横线(宽>高*2) 且在数字下方
    lines=[]
    for c in comps2:
        if c is main: continue
        cx0,cy0,cx1,cy1,wc,hc=c[:6]
        if wc> hc*1.5 and wc>=4 and cy0>=main[1]:  # 横线在主数字下方
            lines.append((cx0,cx1,cy0,cy1,wc,hc))
    print(f"x[{nx0}-{nx1}] crop{w}x{h} 主数字宽={mw} 下划线数={len(lines)}: {[(l[4],l[5]) for l in lines]}")
