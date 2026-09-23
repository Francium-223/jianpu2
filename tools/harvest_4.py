# -*- coding: utf-8 -*-
"""收割真实 '4' 样本(人工确认过的): band7 嘀哩哩那 4 个清晰的 4 + 跨语料小椭圆候选中的4。
提取裁剪存为 digit=4 训练样本, 供重训 digit 头。先只从 spring 收 4 个已确认的四。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[7]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
outdir="train-work/real_4"; os.makedirs(os.path.join(outdir,"png"),exist_ok=True)
import json
man=[]
# spring 中 band7 的 4 个 4 (x21,x46,x72,x99) — 人工放大确认都是4
four_x=[(21,32),(46,57),(72,82),(99,110)]
for i,(nx0,nx1) in enumerate(four_x):
    # 找对应块
    for (rx0,rx1,ry0,ry1) in T.crop_note_regions(sub):
        if abs(rx0-nx0)<4:
            y1=min(ry1,be[1]) if (be and ry0<=be[1]+2) else ry1
            crop=Q.bound_to_note_row(row_gray,rx0,rx1,ry0,ry1,be)
            if crop is None or crop.size==0: continue
            fn=f"png/r4_{i:03d}.png"; Image.fromarray(crop).save(os.path.join(outdir,fn))
            man.append({"image":os.path.join(outdir,fn).replace("\\","/"),"text":"4","src":"spring"})
            break
json.dump(man, open(os.path.join(outdir,"manifest.json"),"w"))
print("spring 已收真实4:",len(man), man)
