# -*- coding: utf-8 -*-
"""基线: 对 spring 跑当前 transcribe_qwen, 输出 (a) 完整对齐分 (b) 两处目标块的预测+细节。
用于改前/改后对比。"""
import os,sys,re; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, torch, torch.nn as nn
from PIL import Image
import transcribe as T
from note_prep import _crop_content
from geo_detect import geo_detect, _components
from classify_block import classify_block
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q

visual=load_qwen_visual(); proc=get_processor()
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval(); heads=heads.to("cuda")
is_note=nn.Linear(2048,1); sd=torch.load("models/qwen-mt-v1/is_note.pt",map_location="cpu")
if "linear.weight" in sd: sd={"weight":sd["linear.weight"],"bias":sd["linear.bias"]}
is_note.load_state_dict(sd); is_note.eval(); is_note=is_note.to("cuda")
ZERO_CONF_THR=0.60; IS_NOTE_THR=0.5; DIG=Q.DIGIT

def p_note(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float().unsqueeze(0)
        return torch.sigmoid(is_note(f)).item()

def predict(crop, zero_gate=True):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        out={k:heads[k](f.unsqueeze(0)) for k in Q.DIM_N}
        dp=torch.softmax(out["digit"],-1)
    res={k:int(out[k].argmax(dim=1).item()) for k in Q.DIM_N}
    p0=dp[0,7].item()
    if zero_gate and res["digit"]==7 and p0<ZERO_CONF_THR:
        da=dp[0].clone(); da[7]=-1e9; res["digit"]=int(da.argmax(dim=0).item())
    return res, p0

# 逐带切块预测, 收集 token 序列 & 记录两处目标块
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
toks=[]; targets={}
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
        btype=classify_block(crop)
        if btype=="dash": toks.append("-"); continue
        if btype=="rest": toks.append("0"); continue
        if btype!="digit": continue
        pn=p_note(crop)
        if pn<IS_NOTE_THR: continue
        res,p0=predict(crop)
        # 记录目标块: 含"下划线低8点残留"候选(底部暗纹) & 裸数字判0
        m=crop<170; Hh,Ww=m.shape
        bottom_dark=int(m[int(Hh*0.66):].sum())
        res["beam"]=geo_detect(crop)["beam"]
        tok=Q.to_token(res)
        # 目标1: token 低八度点数>=2(异常 q,,1/q,,,3)
        if res["low"]>=2: targets.setdefault("low_over",[]).append((band,nx0,res, geo_detect(crop), bottom_dark))
        # 目标2: digit==0 且是裸数字(p0高)
        if res["digit"]==7: targets.setdefault("as0",[]).append((band,nx0,p0))
        toks.append(tok)
print("序列:", " ".join(toks))
print("\n=== 目标1: low>=2 的块(疑似 q,, x 误判) ===")
for b in targets.get("low_over",[]):
    band,nx,res,geo,bd=b
    print(f"  带{band} x{~nx}: res={ {k:v for k,v in res.items() if k in ('digit','low','voice','beam')} } geo={geo} 底部暗px={bd}")
print("\n=== 目标2: digit==0 的块(含裸数字假0) ===")
for b in targets.get("as0",[]):
    band,nx,p0=b
    print(f"  带{band} x{nx}: p0={p0:.2f} {'<0.60门(不拦)' if p0>=ZERO_CONF_THR else '<0.60门(拦)'}: {p0:.2f}")
