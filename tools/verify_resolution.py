# -*- coding: utf-8 -*-
"""验证"分辨率是否够": 把 x584/x612(s1), x639/x664(q1) 裁剪放大到不同倍, 看下划线
双线(s) vs 单线(q) 是否在高分辨率下可分——即下划线区域是否有"空行分隔的双峰"。"""
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
def profile_at_scale(crop, scale):
    img=Image.fromarray(crop)
    if scale>1:
        img=img.resize((img.width*scale, img.height*scale), Image.LANCZOS)
    m=np.asarray(img)<170
    rows=m.sum(axis=1)
    return rows.tolist()
from collections import defaultdict
byx={}
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (580<=nx0<=700): continue
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    tag="s1" if nx0 in (584,612) else "q1" if nx0 in (639,664) else "?"
    byx[nx0]=(crop,tag)
for nx0 in sorted(byx):
    crop,tag=byx[nx0]
    print(f"\n=== x{nx0} [{tag}] 原crop {crop.shape} ===")
    for sc in (1,2,3):
        rows=profile_at_scale(crop,sc)
        # 只看下划线区(最后20%行)
        tail=rows[-max(2,len(rows)//4):]
        print(f"  放大{sc}x: 底部行剖面={tail}")
