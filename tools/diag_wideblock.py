# -*- coding: utf-8 -*-
"""检查那些 54-81px 宽的块(带5 x77/x427, 带7 x583/x662)内部: 含几个数字状连通域?
看是否 '数字+数字' 或 '数字+下划线' 粘成一个块。打印连通域明细。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from geo_detect import _components
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
targets={5:[77,427],7:[583,662]}
for band,xs in targets.items():
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        if not any(abs(nx0-x)<12 for x in xs): continue
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        comps2=_components(crop<170)
        dig=[c for c in comps2 if c[5]>=14 and c[5]>c[4] and c[4]>=5]  # 数字状
        print(f"\n带{band} 块 x[{nx0}-{nx1}] 裁{crop.shape[1]}x{crop.shape[0]}:")
        print(f"  数字状连通域 {len(dig)} 个:")
        for c in dig[:6]:
            print(f"    x[{c[0]}-{c[2]}] y[{c[1]}-{c[3]}] w={c[4]} h={c[5]}")
