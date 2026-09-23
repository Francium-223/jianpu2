# -*- coding: utf-8 -*-
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from geo_detect import _components, geo_detect
IMG="train-work/gt/时间都去哪了.jpg"
arr=np.asarray(Image.open(IMG).convert("L")); content=arr<T.TOL
bi=10; s,e=T.fine_rows(content,T.ROW_GAP)[bi]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    ths=sorted(c[5] for c in thin); hb=ths[len(ths)//2]; bars=[c for c in thin if c[5]>=0.8*hb and c[5]>=20]
    if len(bars)>=T.BAR_THR:
        yt=sorted(b[1] for b in bars); ym=yt[len(yt)//2]; bars=[b for b in bars if abs(b[1]-ym)<=24]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (658<=nx0<=680): continue
    crop=row_gray[max(0,ny0-8):min(ny1,be[1] if be else ny1)+8, max(0,nx0-8):nx1+8]
    m=crop<170; Hh,Ww=m.shape; comps2=_components(m); main=max(comps2,key=lambda c:c[5])
    print(f"裁剪{Ww}x{Hh} 主数字 v[{main[1]}-{main[3]}] 行剖面={m.sum(axis=1).tolist()}")
    for c in comps2:
        if c is main: continue
        x0,y0,x1,y1,w,h=c[:6]
        print(f"  副 x[{x0}-{x1}] y[{y0}-{y1}] w{w} h{h} asp{w/max(h,1):.1f} {'下方' if y0>main[3]-1 else '?'}")
    print("geo:", geo_detect(crop))
