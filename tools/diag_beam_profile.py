# -*- coding: utf-8 -*-
"""s1(x584/x612) vs q1(x639/x664) vs 单/双线参考(x21 s4, x367 q2) 的下划线行剖面:
打印下划线区域每行暗px, 看 s(双线)是否有两个暗峰/两行显著, q(单线)是否一行。"""
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
    w=nx1-nx0
    if w>20 or ny0>be[1]: continue
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    m=crop<170; Hh,Ww=m.shape
    rows=m.sum(axis=1)
    # 数字主体: 前部; 找下划线区域 = 数字底(rows最大峰之后)的连续暗行
    # 打印整列行剖面(每3行)
    prof=[int(v) for v in rows]
    tag = "s1" if nx0 in (584,612) else "q1" if nx0 in (639,664) else ("q2" if nx0==689 else ("s4" if nx0 in (21,46) else "q2b" if nx0==367 else "?"))
    print(f"x[{nx0}-{nx1}] {tag} W={Ww} 行剖面={prof}")
