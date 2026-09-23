# -*- coding: utf-8 -*-
"""band3 块 x[462-473]: 打印 bound 后 crop 的 geo_detect 各值 + 预测. 看 q,,,3 哪来的。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image
import transcribe as T
from note_prep import _crop_content
from geo_detect import geo_detect, _components
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval()
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda")
DIG=Q.DIGIT
def predict(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB"))
    enc=proc(cimg,return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        out={k:heads[k](f.unsqueeze(0)) for k in Q.DIM_N}
    return {k:int(out[k].argmax(dim=1).item()) for k in Q.DIM_N}
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[3]; sub=content[s:e+1]
comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
be=(0,48)
row_gray=arr[s:e+1]
for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
    if abs(nx0-462)<12:
        y1=min(ny1,be[1]) if ny0<=be[1]+2 else ny1
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None: print("bound->None(歌词块)"); continue
        res=predict(crop)
        geo=geo_detect(crop)
        print(f"块 x[{nx0}-{nx1}] 原ny[{ny0}-{ny1}] 收敛y1={y1} crop={crop.shape}")
        print(f"  digit头 res={res}  geo={geo}  token={Q.to_token(res)}")
        # 裁剪内容特征
        m=crop<170; Hh,Ww=m.shape
        print(f"  暗px={int(m.sum())} 底部1/3暗px={int(m[int(Hh*0.66):].sum())} 底行分布={m.sum(axis=1)[-6:]}")
