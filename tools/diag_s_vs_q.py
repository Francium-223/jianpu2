# -*- coding: utf-8 -*-
"""对比 s1(x584/x612 双下划线) vs q1(x639/x664 单下划线) 的下划线几何:
下划线连通域 高h、宽w、纵向暗px 是否分层。用于可靠区分 s(2线) vs q(1线)。"""
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
    # 只要 x580-700 的 1/2 区
    if not (580 <= nx0 <= 700): continue
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    comps2=_components(crop<170); main=max(comps2,key=lambda c:c[5])
    # 下划线连通域(横线, 主数字下方)
    lines=[]
    for c in comps2:
        if c is main: continue
        cx0,cy0,cx1,cy1,wc,hc=c[:6]
        if wc>=hc*1.5 and wc>=5 and cy0>=main[1]:
            lines.append((cx0,cy0,cx1,cy1,wc,hc))
    print(f"x[{nx0}-{nx1}] {'s1' if nx0 in (584,612) else ('q1' if nx0 in (639,664) else '2' if nx0==689 else '?')}: 下划线={[(f'w{l[4]}h{l[5]}', ) for l in lines]} 主数字底={main[3]}")
