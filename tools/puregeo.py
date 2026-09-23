# -*- coding: utf-8 -*-
"""纯几何诊断(不加载Qwen): 对时间都去哪了所有块, 跑 geo_detect, 输出 beam/low/voice.
找 该有下划线(时值)/低八点 但 geo 漏检的块. 不依赖 Qwen(不崩)."""
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
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
        gd=geo_detect(crop)
        m=crop<170; comps2=_components(m); main=max(comps2,key=lambda c:c[5])
        # 找 数字下方有横线(下划线笔划) 但 geo beam=0 的块(漏时值)
        has_line=any(c[4]>=2*c[5] and c[4]>=10 and c[1]>main[3]-1 for c in comps2 if c is not main)
        # 找 数字下方有点(低八) 但 geo low=0
        has_lowdot=any(0.4<=c[4]/max(c[5],1)<=2.5 and 3<=c[4]<=14 and 3<=c[5]<=14 and c[1]>main[3] and c[0]>=main[0] and c[2]<=main[2] for c in comps2 if c is not main)
        flag=""
        if has_line and gd["beam"]==0: flag+=" 漏时值下划线!"
        if has_lowdot and gd["low"]==0: flag+=" 漏低八点!"
        if flag:
            print(f"带{bi} x[{nx0}-{nx1}] geo=(beam{gd['beam']} low{gd['low']} voice{gd['voice']}){flag}")
