# -*- coding: utf-8 -*-
"""复现转写, 但记录 每个token 的来源(带band, x坐标), 用于把错误位置映射到原图。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image
import transcribe as T
from note_prep import _crop_content
from geo_detect import geo_detect
from classify_block import classify_block
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q
visual=load_qwen_visual(); proc=get_processor()
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval(); heads=heads.to("cuda")
is_note=nn.Linear(2048,1); sd=torch.load("models/qwen-mt-v1/is_note.pt",map_location="cpu")
if "linear.weight" in sd: sd={"weight":sd["linear.weight"],"bias":sd["linear.bias"]}
is_note.load_state_dict(sd); is_note.eval(); is_note=is_note.to("cuda")
IS_NOTE_THR=0.5; ZERO=0.75
def p_note(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float().unsqueeze(0)
        return torch.sigmoid(is_note(f)).item()
def predict(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        out={k:heads[k](f.unsqueeze(0)) for k in Q.DIM_N}; dp=torch.softmax(out["digit"],-1)
    res={k:int(out[k].argmax(dim=1).item()) for k in Q.DIM_N}
    if res["digit"]==7 and dp[0,7].item()<ZERO:
        da=dp[0].clone(); da[7]=-1e9; res["digit"]=int(da.argmax(dim=0).item())
    res["beam"]=geo_detect(crop)["beam"]
    return res
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
seq=[]
for band,(s,e) in enumerate(T.fine_rows(content,T.ROW_GAP)):
    sub=content[s:e+1]; H=e-s+1
    if T.count_bars(sub,H)<T.BAR_THR: continue
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        bt=classify_block(crop)
        if bt=="dash": seq.append((band,nx0,"-")); continue
        if bt=="rest": seq.append((band,nx0,"0")); continue
        if bt!="digit": continue
        if p_note(crop)<IS_NOTE_THR: continue
        res=predict(crop); tok=Q.to_token(res)
        seq.append((band,nx0,tok))
# 打印 带序号+token 序列, 供定位
for i,(band,x,tok) in enumerate(seq):
    print(f"{i:3d} 带{band} x{x:4d}  {tok}")
