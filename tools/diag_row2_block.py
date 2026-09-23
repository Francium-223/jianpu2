# -*- coding: utf-8 -*-
"""看 x[462-473] 块被 geo_detect 判 low 的具体连通域: 打印该块所有连通域及各自被判成什么。"""
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
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (455<=nx0<=480): continue
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    print(f"=== 块 x[{nx0}-{nx1}] 裁{crop.shape} ===")
    comps2=_components(crop<170)
    main=max(comps2,key=lambda c:c[5])
    print(f"主数字: x[{main[0]}-{main[2]}] y[{main[1]}-{main[3]}] w={main[4]} h={main[5]}")
    for c in comps2:
        if c is main: continue
        cx0,cy0,cx1,cy1,w,h=c[:6]
        aspect=w/max(h,1)
        print(f"  连通域 x[{cx0}-{cx1}] y[{cy0}-{cy1}] w={w} h={h} aspect={aspect:.2f} "
              f"{'is_line' if (aspect>2.5 and w>12) else ''}{'is_dot' if (0.4<=aspect<=2.5 and 3<=w<=14 and 3<=h<=14) else ''}")
