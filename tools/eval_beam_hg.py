import re
# -*- coding: utf-8 -*-
"""对比 spring 每个数字块的 Qwen beam头 vs geo beam, 以及 GT 期望 beam。
判断 该用头 还是 geo。按GT逐位对齐后统计。"beam头对/geo对"。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
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
def beam_both(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        hb=int(heads["beam"](f.unsqueeze(0)).argmax(dim=1).item())
    gb=geo_detect(crop)["beam"]
    return hb,gb
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
# 逐带收集块与GT序列(用对齐), 统计 GT beam vs 头beam vs geo beam
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtrows=[[x for x in l.replace("("," ").replace(")"," ").split() if x] for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l) and "=" not in l and "/" not in l]
hd_ok=geo_ok=0; tot=0
for bi,band in enumerate([i for i,(s,e) in enumerate(T.fine_rows(content,T.ROW_GAP)) if T.count_bars(content[s:e+1],e-s+1)>=T.BAR_THR]):
    if bi>=len(gtrows): break
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    gtb=[Q.DIM_N and token_to_json(x)["beam"] for x in gtrows[bi]] if False else []
    from token_json import token_to_json
    gtb=[token_to_json(x)["beam"] for x in gtrows[bi]]
    j=0
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        w=nx1-nx0; h=y1-ny0
        if w>20 or h<10 or ny0>be[1]: continue
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        try: hb,gb=beam_both(crop)
        except Exception: continue
        if j<len(gtb):
            gt=gtb[j]
            if hb==gt: hd_ok+=1
            if gb==gt: geo_ok+=1
            tot+=1
        j+=1
print(f"样本 {tot}: Qwen beam头命中={hd_ok}({100*hd_ok/max(tot,1):.0f}%)  geo beam命中={geo_ok}({100*geo_ok/max(tot,1):.0f}%)")
