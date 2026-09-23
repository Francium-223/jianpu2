# -*- coding: utf-8 -*-
"""对照: 真低八度点(如 ,5) 的 点y位置 vs 数字底 & 下划线; 对比 误判的 x[462-473] 点y[46-49]。
目的: 找"紧贴数字底"判据, 把远处(歌词)的点排除出 low。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[3]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
def analyze(crop,label):
    comps2=_components(crop<170); main=max(comps2,key=lambda c:c[5])
    mb=main[3]  # 数字底
    print(f"{label}: 数字底y={mb} 主高={main[5]}")
    for c in comps2:
        if c is main: continue
        cx0,cy0,cx1,cy1,w,h=c[:6]
        asp=w/max(h,1)
        kind="line" if (asp>2.5 and w>12) else "dot" if (0.4<=asp<=2.5 and 3<=w<=14 and 3<=h<=14) else "?"
        print(f"   y[{cy0}-{cy1}] w={w} h={h} {kind} | 距数字底={cy0-mb}")
# 真低八度 (,5 块): 找 x[23-34] 附近的 (数字5 下方有点)
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    w=nx1-nx0
    if w>20 or ny0>be[1]: continue
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    # 只分析 带 down-dot 的块
    comps2=_components(crop<170); main=max(comps2,key=lambda c:c[5])
    has_dot_below=any(0.4<=(c[4]/max(c[5],1))<=2.5 and 3<=c[4]<=14 and 3<=c[5]<=14 and c[1]>main[3]+2 for c in comps2 if c is not main)
    if has_dot_below and nx0<60:
        analyze(crop, f"真低八度(,5) x{nx0}")
# 误判块
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if abs(nx0-462)<3:
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        analyze(crop, "误判块 x462(3)")
