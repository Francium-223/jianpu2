# -*- coding: utf-8 -*-
"""band9 真'-'杠块 x[451-481]: 为什么 classify_block 判 empty 而非 dash?
打印裁剪的连通域数量/暗px/几何。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from classify_block import classify_block
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[9]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (445<=nx0<=485): continue
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    print(f"块 x[{nx0}-{nx1}] ny[{ny0}-{ny1}] 裁{crop.shape}")
    m=crop<170; print(f"  暗px={int(m.sum())} 行剖面={m.sum(axis=1).tolist()}")
    comps2=_components(m)
    print(f"  连通域 {len(comps2)} 个:")
    for c in comps2:
        print(f"    x[{c[0]}-{c[2]}] y[{c[1]}-{c[3]}] w={c[4]} h={c[5]} aspect={c[4]/max(c[5],1):.1f}")
    print(f"  classify_block = {classify_block(crop)}")
