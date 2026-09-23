# -*- coding: utf-8 -*-
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from geo_detect import _components
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
# 带10 x501-512 块
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (495<=nx0<=515): continue
    crop=row_gray[max(0,ny0-8):min(ny1,be[1] if be else ny1)+8, max(0,nx0-8):nx1+8]
    if crop.size==0: continue
    m=crop<170; Hh,Ww=m.shape; comps2=_components(m); main=max(comps2,key=lambda c:c[5])
    print(f"裁剪 {Ww}x{Hh} 主数字 y[{main[1]}-{main[3]}]")
    print("行剖面:", m.sum(axis=1).tolist())
    for c in comps2:
        if c is main: continue
        print(f"  副 x[{c[0]}-{c[2]}] y[{c[1]}-{c[3]}] w{c[4]} h{c[5]} aspect{c[4]/max(c[5],1):.1f}")
