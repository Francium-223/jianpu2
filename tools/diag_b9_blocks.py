# -*- coding: utf-8 -*-
"""band9: 看 crop_note_regions 切出的块, 是否包含 y[0-6] 的顶部横线(-杠 vs 下划线)。
并打印 每个块的 classify_block 判定 + 它实际覆盖的 y 范围, 找出'-'未被切出的原因。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from classify_block import classify_block
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
print("band9 crop_note_regions 块:")
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    # 记录原始块(未收敛)的 y 范围
    bt=classify_block(crop)
    # 是否含 y0-6 顶线: 检查裁剪顶部行
    m=crop<170; top=m[:8].sum()
    print(f"  x[{nx0}-{nx1}] ny[{ny0}-{ny1}] 收敛y1={y1} 裁{crop.shape[1]}x{crop.shape[0]} classify={bt} 顶部暗px={int(top)}")
