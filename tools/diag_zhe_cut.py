# -*- coding: utf-8 -*-
"""第二行 '这里' 的 '这' 上面那个音符块: 打印其裁剪范围与暗像素, 看是否把歌词'这'卷进。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[3]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
print("bar_extent(音符行)",be)
# 找 x~30-90 的块('这'上方)
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if nx0<100:
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        crop=arr[s+max(0,ny0-T.PAD):y1+T.PAD, max(0,nx0-T.PAD):nx1+T.PAD]
        print(f"块 x[{nx0}-{nx1}] 原ny[{ny0}-{ny1}] 收敛后y1={y1} 裁剪{crop.shape} 含歌词?{y1>be[1]}")
# 列暗像素分布, '这'字上沿可能到哪
print("\n列暗像素(x0-90, 带内):")
for x in range(20,95,3):
    print(f"  x{x}: 暗px={int(sub[:,x].sum())}")
