# -*- coding: utf-8 -*-
"""第一行: 看最后一个单独的 '3'(里上方) 与旁边 '0' 的裁剪, 以及预测概率。
判断 3 为何被判0: 是裁剪把右邻0/下划线卷进来, 还是3本身形状像0。"""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image, ImageDraw, ImageFont
import transcribe as T
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval()
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda")
DIG=Q.DIGIT
def probs(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB"))
    enc=proc(cimg,return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        dp=torch.softmax(heads["digit"](f.unsqueeze(0)),-1)[0]
    return dp
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[1]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
idx=0
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    w=nx1-nx0; h=y1-ny0
    if w>20 or h<10 or ny0>be[1]: continue
    crop=row_gray[max(0,ny0-T.PAD):y1+T.PAD, max(0,nx0-T.PAD):nx1+T.PAD]
    if crop.size==0: continue
    dp=probs(crop)
    top3=torch.topk(dp,3)
    pred=DIG[int(dp.argmax())]
    print(f"块{idx:2d}: x[{nx0}-{nx1}] w={w} h={h} pred={pred} | top3={[(DIG[int(t)],round(float(v),3)) for t,v in zip(top3.indices,top3.values)]}")
    idx+=1
# 放大 最后3与0 区域
im=Image.open(F)
im.crop((310,112,470,180)).resize((640,272),Image.LANCZOS).save("train-work/zoom_r1_3_0.png")
print("saved zoom_r1_3_0.png")
