# -*- coding: utf-8 -*-
"""扫 OT 权重 w1(geo惩罚惩罚), 找使 OT 命中率最高的— 若 OT 在某个 w1 超过纯geo74%, 则值得用 OT。
逐带严格对齐(用 digit 匹配块↔GT), 对比 head/geo/OT@不同w1。"""
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
from token_json import token_to_json
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval()
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda")
def beam_probs(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        return torch.softmax(heads["beam"](f.unsqueeze(0)),-1)[0].cpu().numpy()
CAND=[0,1,2,3,4]
def ot(bp,gb,w1):
    best=1e9;bb=None
    for b in CAND:
        s=w1*abs(b-gb)+(1.0-bp[b])
        if s<best: best=s;bb=b
    return bb
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtrows=[[x for x in l.replace("("," ").replace(")"," ").split() if x] for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l) and "=" not in l and "/" not in l]
def normal_beam(gtrow):
    out=[]
    for x in gtrow:
        if x=="-": continue
        j=token_to_json(x)
        if j["digit"] in ("","-"): continue
        out.append(j["beam"])
    return out
bands=[i for i,(s,e) in enumerate(T.fine_rows(content,T.ROW_GAP)) if T.count_bars(content[s:e+1],e-s+1)>=T.BAR_THR]
data=[]
for bi,band in enumerate(bands):
    if bi>=len(gtrows): break
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    gt=normal_beam(gtrows[bi]); gi=0
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        w=nx1-nx0; h=y1-ny0
        if w>20 or h<10 or ny0>be[1]: continue
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        bp=beam_probs(crop); gb=geo_detect(crop)["beam"]
        if gi<len(gt):
            data.append((bp, gb, gt[gi]))
        gi+=1
# 每个样本: (bp, gb, gt)
print("样本",len(data))
def acc(sel):
    return sum(1 for bp,gb,gt in data if sel(bp,gb)==gt)
print(f"head: {acc(lambda bp,gb:int(bp.argmax()))}")
print(f"geo : {acc(lambda bp,gb:gb)}")
for w1 in [0.2,0.4,0.6,0.8,1.0,1.5,2.0]:
    print(f"ot w1={w1}: {acc(lambda bp,gb:ot(bp,gb,w1))}")
