# -*- coding: utf-8 -*-
"""把 spring 整页谱 按当前切分逻辑(crop_note_regions + bar_extent 音符行收敛)切块,
把每个块框画出来, 并标上模型预测的 token。生成: spring_cut_full.png """
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image, ImageDraw, ImageFont
import transcribe as T
from note_prep import _crop_content
from geo_detect import geo_detect, _components
from classify_block import classify_block
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q

F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL

visual=load_qwen_visual(); proc=get_processor()
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in Q.DIM_N.items()})
heads.load_state_dict(torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")); heads.eval()
heads=heads.to("cuda")
is_note=nn.Linear(2048,1); sd=torch.load("models/qwen-mt-v1/is_note.pt",map_location="cpu")
if "linear.weight" in sd: sd={"weight":sd["linear.weight"],"bias":sd["linear.bias"]}
is_note.load_state_dict(sd); is_note.eval(); is_note=is_note.to("cuda")
device="cuda"; IS_NOTE_THR=0.5; ZERO_CONF_THR=0.75
DIG=Q.DIGIT

def p_note(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB"))
    enc=proc(cimg,return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float().unsqueeze(0)
        return torch.sigmoid(is_note(f)).item()

def predict(crop, apply_zero_gate=True):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB"))
    enc=proc(cimg,return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        out={k:heads[k](f.unsqueeze(0)) for k in Q.DIM_N}
        dp=torch.softmax(out["digit"],-1)
    res={k:int(out[k].argmax(dim=1).item()) for k in Q.DIM_N}
    if apply_zero_gate and res["digit"]==7:
        p0=dp[0,7].item()
        if p0<ZERO_CONF_THR:
            da=dp[0].clone(); da[7]=-1e9; res["digit"]=int(da.argmax(dim=0).item())
    res["beam"]=geo_detect(crop)["beam"]
    return res

out=Image.open(F).convert("RGB"); dr=ImageDraw.Draw(out)
font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",10)
rowmap={}
segs=T.fine_rows(content,T.ROW_GAP)
overall=0
for band,(s,e) in enumerate(segs):
    sub=content[s:e+1]; H=e-s+1
    if T.count_bars(sub,H)<T.BAR_THR: continue
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        ths=sorted(c[5] for c in thin); hb=ths[len(ths)//2]
        bars=[c for c in thin if c[5]>=0.8*hb and c[5]>=20]
        if len(bars)>=T.BAR_THR:
            ytops=sorted(b[1] for b in bars); ym=ytops[len(ytops)//2]
            bars=[b for b in bars if abs(b[1]-ym)<=24]   # y-top主簇, 剔除伴奏杠等离群
            if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        w=nx1-nx0; h=y1-ny0
        if w>20 or h<10 or ny0>(be[1] if be else 1e9): continue  # 只画音符行内
        crop=row_gray[max(0,ny0-T.PAD):y1+T.PAD, max(0,nx0-T.PAD):nx1+T.PAD]
        if crop.size==0: continue
        btype=classify_block(crop)
        label=None; col=(0,90,255)
        if btype=="dash":
            label="-"; col=(150,150,150)
        elif btype=="rest":
            label="0"; col=(0,150,0)
        elif btype=="digit":
            pn=p_note(crop)
            if pn<IS_NOTE_THR: col=(200,0,0)
            else:
                res=predict(crop); label=Q.to_token(res)
        cx0=max(0,nx0-T.PAD); cx1=min(arr.shape[1]-1,nx1+T.PAD)
        cy0=max(0,s+ny0-T.PAD); cy1=min(arr.shape[0]-1,s+y1+T.PAD)
        dr.rectangle([cx0,cy0,cx1,cy1],outline=col,width=1)
        if label:
            dr.text((cx0+1,cy0+1),label,fill=col,font=font)
        overall+=1
out.save("train-work/spring_cut_full.png")
print(f"切块 {overall} -> spring_cut_full.png")
