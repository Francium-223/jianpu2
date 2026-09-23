# -*- coding: utf-8 -*-
"""定位 时间都去哪了 中被标错的块('0'被判4, 'q5'当5, ',6'当6, 's6'缺低八), 看 geo beam/low.
找到后对比 GT 该是什么。"""
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, torch, torch.nn as nn
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
import pipeline as P
from geo_detect import geo_detect, _components
IMG="train-work/gt/时间都去哪了.jpg"
arr=np.asarray(Image.open(IMG).convert("L")); content=arr<T.TOL
for bi,(s,e) in enumerate(T.fine_rows(content,T.ROW_GAP)):
    sub=content[s:e+1]; H=e-s+1
    if T.count_bars(sub,H)<T.BAR_THR: continue
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        ths=sorted(c[5] for c in thin); hb=ths[len(ths)//2]; bars=[c for c in thin if c[5]>=0.8*hb and c[5]>=20]
        if len(bars)>=T.BAR_THR:
            yt=sorted(b[1] for b in bars); ym=yt[len(yt)//2]; bars=[b for b in bars if abs(b[1]-ym)<=24]
            if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        bt,tok=P.classify_token(crop)
        if not tok: continue
        gd=geo_detect(crop)
        m=crop<170; main=max(_components(m),key=lambda c:c[5])
        # 找有下划线(beam)但 geo 漏 / 低八点漏 的异常
        # 打印所有含 0/时值问题 的线索块(带0/4/无q但GT是q 等)——先宽泛打印每个块的 geo + tok, 我自己看
        if tok in ("4","5","6","3","1","0") or "0" in tok:
            print(f"带{bi} x[{nx0}-{nx1}] tok={tok} geo=(beam{gd['beam']} low{gd['low']} voice{gd['voice']} dotted{gd['dotted']})")
