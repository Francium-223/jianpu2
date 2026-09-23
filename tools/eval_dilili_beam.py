# -*- coding: utf-8 -*-
"""聚焦 band7 末尾 '11 11 2' 四个1: 打印 每块 概率头beam-top、geo线数、GT期望。
确认 geo 是否把 s1(双线) 数成 q1(单线)。"""
import os,sys,re; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image
import transcribe as T
from note_prep import _crop_content
from geo_detect import geo_detect
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval()
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda")
BN=["-","q","s","d","h"]
def bprobs(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        bp=torch.softmax(heads["beam"](f.unsqueeze(0)),-1)[0]
    return bp.cpu().numpy()
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[7]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
print("band7 末尾 1 1 1 1 2 (GT: s s q q q):")
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (580<=nx0<=700): continue
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    bp=bprobs(crop); gb=geo_detect(crop)["beam"]
    top2=np.argsort(-bp)[:2]
    tstr=", ".join(f"{BN[int(t)]}={bp[t]:.2f}" for t in top2)
    print(f"x[{nx0}-{nx1}]: 头top2=[{tstr}] geo={gb}")
