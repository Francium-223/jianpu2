# -*- coding: utf-8 -*-
"""统一: 一次运行完成 spring 转写+画图. pipeline 切块 -> Qwen3-VL-4B(批量)认数字 + geo 认符号
-> 同时(a)画框标token (b)输出序列+OK. 保证 图==转写."""
import os,sys,re; sys.path.insert(0,"tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM","false")
MODEL="D:/Documents_D/jianpu2/models/Qwen3-VL-2B-Instruct"
import numpy as np, torch
from PIL import Image, ImageDraw, ImageFont
from transformers import AutoProcessor, AutoModelForImageTextToText
import transcribe as T, transcribe_qwen as Q
from classify_block import classify_block
from geo_detect import geo_detect
from difflib import SequenceMatcher
from token_json import token_to_json
BEAM_PRE={0:"",1:"q",2:"s",3:"d",4:"h"}
IMG="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(IMG).convert("L")); content=arr<T.TOL
# 1) 切块
blocks=[]  # (s, nx0,nx1,ny0,ny1, crop, btype)
for s,e in T.fine_rows(content,T.ROW_GAP):
    sub=content[s:e+1]; H=e-s+1
    if T.count_bars(sub,H)<T.BAR_THR: continue
    row_gray=arr[s:e+1]; be=Q.bar_extent(sub)
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        blocks.append((s,nx0,nx1,ny0,ny1,crop,classify_block(crop)))
print(f"切块 {len(blocks)}", flush=True)
# 2) 批量 Qwen3-4B 认数字(只对 digit 块)
proc=AutoProcessor.from_pretrained(MODEL, trust_remote_code=True)
model=AutoModelForImageTextToText.from_pretrained(MODEL, device_map=None, trust_remote_code=True, dtype=torch.bfloat16).eval()
DP="这个简谱音符的数字是几? 只输出一个数字(1-7或0)。"
digit_idx=[i for i,b in enumerate(blocks) if b[6]=="digit"]
imgs=[]
for i in digit_idx:
    crop=blocks[i][5]; im=Image.fromarray(crop).convert("RGB")
    imgs.append(im)   # 不放大: 原尺寸 crop, patch 少 -> 快
digits={}
for k,i in enumerate(digit_idx):
    im=imgs[k]
    text=proc.apply_chat_template([{"role":"user","content":[{"type":"image"},{"type":"text","text":DP}]}], tokenize=False, add_generation_prompt=True)
    enc=proc(images=im, text=text, return_tensors="pt")
    enc={x:(v.to(model.device) if torch.is_tensor(v) else v) for x,v in enc.items()}
    with torch.no_grad(): out=model.generate(**enc, max_new_tokens=2, do_sample=False)
    s_=proc.decode(out[0][enc["input_ids"].shape[1]:], skip_special_tokens=True).strip()
    m=re.search(r"[0-9]", s_); digits[i]=m.group(0) if m else "?"
    if (k+1)%20==0: print(f"  数字 {k+1}/{len(digit_idx)}", flush=True)
# 3) 组装 + 画图(同一次运行)
out=Image.open(IMG).convert("RGB"); dr=ImageDraw.Draw(out); font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",10)
toks=[]
for i,(s,nx0,nx1,ny0,ny1,crop,bt) in enumerate(blocks):
    col=(0,90,255); lab=None
    if bt=="dash": col=(150,150,150); lab="-"; toks.append("-")
    elif bt=="rest": col=(0,150,0); lab="0"; toks.append("0")
    elif bt=="digit":
        d=digits.get(i,"?"); gd=geo_detect(crop)
        lab=BEAM_PRE[gd["beam"]]+","*gd["low"]+"'"*gd["voice"]+d+"."*gd["dotted"]
        toks.append(lab)
    else: continue
    x0=max(0,nx0-6); x1=min(arr.shape[1]-1,nx1+6); cy0=max(0,s+ny0-6); cy1=min(arr.shape[0]-1,s+int(ny1)+6)
    dr.rectangle([x0,cy0,x1,cy1],outline=col,width=1)
    if lab: dr.text((x0+1,cy0+1),lab,fill=col,font=font)
out.save("train-work/spring_combo_cut.png")
def key(t):
    j=token_to_json(t); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtl=[l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l)]
gs=" ".join(gtl).replace("("," ").replace(")"," ")
GT=[x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x) or x=="-"]
sm=SequenceMatcher(None,[key(x) for x in toks],[key(x) for x in GT])
ok=sum(i2-i1 for tag,i1,i2,j1,j2 in sm.get_opcodes() if tag=="equal")
print(f"spring 组合: 音{len(toks)} OK={ok}  -> train-work/spring_combo_cut.png")
print("序列:", " ".join(toks))
