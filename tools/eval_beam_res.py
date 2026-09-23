# -*- coding: utf-8 -*-
"""最后一个值得试的: 把 s1/q1 裁剪放大后直接喂 beam 头, 看高分辨率能否让头分清 s/q。
若头在高分辨率下 s/q 分明, 则改输入缩放; 否则确认头也无法从图像区分。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image
import transcribe as T
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in {"beam":5}.items()})
heads.load_state_dict({k:v for k,v in torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu").items() if k.startswith("beam")})
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda"); heads.eval()
BN=["-","q","s","d","h"]
def bhead(crop, scale):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB"))
    if scale>1:
        cimg=cimg.resize((cimg.width*scale,cimg.height*scale),Image.LANCZOS)
    enc=proc(cimg,return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        return torch.softmax(heads["beam"](f.unsqueeze(0)),-1)[0].cpu().numpy()
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[7]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=None
if thin:
    hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
row_gray=arr[s:e+1]
byx={}
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if not (580<=nx0<=700): continue
    y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
    crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
    if crop is None or crop.size==0: continue
    byx[nx0]=crop
for nx0 in sorted(byx):
    tag="s1" if nx0 in (584,612) else "q1" if nx0 in (639,664) else "?"
    crop=byx[nx0]
    print(f"x{nx0}[{tag}]: ", end="")
    for sc in (1,2,3):
        bp=bhead(crop,sc)
        top=np.argsort(-bp)[:2]
        tstr="/".join(f"{BN[int(t)]}:{bp[t]:.2f}" for t in top)
        print(f"  {sc}x[{tstr}]", end="")
    print()
