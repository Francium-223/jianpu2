# -*- coding: utf-8 -*-
"""检查这些被误判成 '-' 的位置(token带'-') 的块, 是否其实是 连音弧(slur) 而非延音杠。
打印 块内主导连通域的几何(是否弧形/贴合形状)."""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
# 检查 band3 (位置21-22 关联 x216-227 附近 有 q7, 和一个 '-').
# 找 band3 所有被判 dash 的块
for band,tag in [(3,"band3 (q6 q7 slur区)"),(7,"band7")]:
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        m=crop<170
        main_h=max(_components(m),key=lambda c:c[4]*c[5],default=None)
        if main_h is None: continue
        cy=(main_h[1]+main_h[3])/2.0; Hh=crop.shape[0]
        if main_h[4]>=15 and main_h[4]>2*main_h[5] and cy<Hh*0.4:
            print(f"[{tag}] x[{nx0}-{nx1}] 裁{crop.shape} 主导线w{main_h[4]}h{main_h[5]} cy={cy:.0f}(块内{cy/Hh:.2f})")
