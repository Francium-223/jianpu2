# -*- coding: utf-8 -*-
"""区分 真'-'(flat 直横线) vs 连音弧(slur 曲线): 看主导横线的"行剖面"是否平整(1行主导) vs 有多行(弧形).
也用一个真'-'杠(带9 x454)对照。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
def prof(band,nx0):
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (rx0,rx1,ry0,ry1) in T.crop_note_regions(sub):
        if abs(rx0-nx0)>12: continue
        y1=min(ry1,be[1]) if (be and ry0<=be[1]+2) else ry1
        crop=Q.bound_to_note_row(row_gray,rx0,rx1,ry0,ry1,be)
        if crop is None or crop.size==0: continue
        m=crop<170
        # 主导横线整块的行剖面(取 线附近)
        print(f"band{band} x{rx0} 裁{crop.shape} 行剖面={m.sum(axis=1).tolist()}")
        return
prof(3,193)   # slur over 6 7
prof(3,259)   # slur over 1 3
prof(9,454)   # real dash -
prof(9,589)   # real dash -
