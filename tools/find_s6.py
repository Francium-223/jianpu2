# -*- coding: utf-8 -*-
"""定位 's6'(缺低八) 和 'qb'3'(误加b) 的块, 看它们的 geo + 几何(低八点/变音).
纯几何部分(geo) 不依赖 Qwen. 但 acc(b) 是 Qwen 头, 需单独确认.
先找 s6 块(十六分6) 和 b3 相关块. """
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from geo_detect import geo_detect, _components
IMG="train-work/gt/时间都去哪了.jpg"
arr=np.asarray(Image.open(IMG).convert("L")); content=arr<T.TOL
# GT 里 s6 和 低八 s 的位置: GT ',5s ,5q ,6s' 等. 
# 找 所有 主数字=6/且含下划线双层(s) 的块, 及 数字3 的块(查b)
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
        crop=row_gray[max(0,ny0-8):min(ny1,be[1] if be else ny1)+8, max(0,nx0-8):nx1+8]
        if crop.size==0: continue
        gd=geo_detect(crop)
        m=crop<170; comps2=_components(m); main=max(comps2,key=lambda c:c[5])
        # 该块数字(主形状) → 看是否含 '3' 或 '6' 主数字
        # 检查是否有 双下划线(s, 两条横线) → beam>=2
        # 是否有低八点(low)
        # 只看 主数字高16+ 的块
        if main[5]<16: continue
        # 找该块 特征: 两条横线(s)→需要 count 数字下方横线
        lines=[c for c in comps2 if c is not main and c[4]>=2*c[5] and c[4]>=10 and c[1]>main[3]-1]
        if gd["beam"]>=2 or (gd["low"]>=1 and len(lines)>=1):
            if main[4]>=8 and 6<=main[4]<=16:
                print(f"带{bi} x[{nx0}-{nx1}] 主w{main[4]}h{main[5]} geo=(beam{gd['beam']} low{gd['low']} voice{gd['voice']}) 横线数{len(lines)}")
