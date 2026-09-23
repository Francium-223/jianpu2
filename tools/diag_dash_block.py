# -*- coding: utf-8 -*-
"""检查 band9 里 延音杠 '-' 的位置: 找 孤单横线(dash) 块, 看 classify_block 判定/裁剪。
同时看 band7 尾部。打印所有 横线型(宽>高*2) 连通域。"""
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
for band in (7,9):
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]; H=e-s+1
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    print(f"\n===== band{band} bar_extent={be} =====")
    row_gray=arr[s:e+1]
    # 这带里所有 '横线型' 连通域(独立横线, 可能=延音杠)
    for c in comps:
        x0,y0,x1,y1,w,h=c[:6]
        if w>=h*2 and w>=8 and y0<=be[1]+2:
            # 用该连通域造一个块, 走 classify_block
            crop=row_gray[max(0,y0-T.PAD):y1+T.PAD, max(0,x0-T.PAD):x1+T.PAD]
            bt=classify_block(crop) if crop.size else "?"
            print(f"  横线连通域 x[{x0}-{x1}] y[{y0}-{y1}] w={w} h={h} 单连通?={sum(1 for cc in comps if cc is c)==1} classify={bt}")
    # crop_note_regions 输出中 dash 判定
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        w=nx1-nx0; h=y1-ny0
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        # 只找 宽横线块
        m=crop<170; Hh,Ww=m.shape
        if Ww>15 and Hh<=8:
            print(f"  宽横线块 x[{nx0}-{nx1}] {Ww}x{Hh} classify={classify_block(crop)}")
