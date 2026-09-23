# -*- coding: utf-8 -*-
"""对比: 真'-'杠块(x451 延音杠) vs 时值下划线块(x193 仅下划线?) 的 横线在块内的纵向位置。
为 classify_block 的 dash 判定(主导宽横线 + 位置偏上) 提供依据。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[9]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
print("band9 bar=%s"%str(be))
# 收集所有块的 主横线位置 + 数字位置
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    m=crop<170; comps2=_components(m)
    # 主横线(最宽横线)
    lines=[c for c in comps2 if c[4]>=2*c[5] and c[4]>=8]
    digs=[c for c in comps2 if c[5]>=14 and c[5]>c[4]]
    Hh=crop.shape[0]
    if lines:
        L=max(lines,key=lambda c:c[4]*c[5])
        cy=(L[1]+L[3])/2
        # 若有数字, 线是在数字上还是下
        dd="无数字"
        if digs:
            d_main=max(digs,key=lambda c:c[5]); dd="数字下方" if cy>d_main[3] else "数字上方/同高"
        print(f"x[{nx0}-{nx1}] 裁H={Hh} 主横线y[{L[1]}-{L[3]}] cy={cy:.0f}(块内{cy/Hh:.2f}) {dd}")
