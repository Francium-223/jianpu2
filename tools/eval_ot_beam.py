# -*- coding: utf-8 -*-
"""优选论 (Optimality Theory) 评估 beam(时值) 判定:
候选集 C = {无时值(b0), q(1), s(2), d(3), h(4)}
约束(按重要性排序):
  C1 几何一致性: 候选beam == geo线数 → 同(0违); 否则按 |beam-geo| 惩罚
  C2 头部一致性: 候选beam == argmax(头) 且概率高 → 低违; 概率低 → 高违
联合分 = w1*|beam-geo| + (1-p_head(beam))  选最小者.
评估: 对每音符, 计算 head方案/geo方案/OT方案 的 beam, 与GT对照, 统计命中率.
逐带用 块↔GT 顺序对齐(GT行去括号, 音符块也排除非digit), 严格逐位比较。"""
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
        bp=torch.softmax(heads["beam"](f.unsqueeze(0)),-1)[0]
    return bp.cpu().numpy()

CAND=[0,1,2,3,4]
def head_argmax(bp): return int(bp.argmax())
def geo_beam(crop): return geo_detect(crop)["beam"]

def ot_beam(bp, gb, w1=1.0):
    # 候选分 = w1*|b-gb| + (1-bp[b]) ; 取最小
    best=None;bestb=None
    for b in CAND:
        s = w1*abs(b-gb) + (1.0-bp[b])
        if best is None or s<best: best=s; bestb=b
    return bestb

F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtrows=[[x for x in l.replace("("," ").replace(")"," ").split() if x] for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l) and "=" not in l and "/" not in l]
# 去 纯-, 只保留真实音符(去掉延音杠 -)
bands=[i for i,(s,e) in enumerate(T.fine_rows(content,T.ROW_GAP)) if T.count_bars(content[s:e+1],e-s+1)>=T.BAR_THR]
hits={"head":0,"geo":0,"ot":0}; tot=0
for bi,band in enumerate(bands):
    if bi>=len(gtrows): break
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    # GT 该行 beam 序列(跳过 延音杠 '-' 等非音符token)
    from token_json import token_to_json as t2j
    gt_beams=[]
    for x in gtrows[bi]:
        if x=="-" : continue
        jx=t2j(x)
        if jx["digit"] in ("","-"): continue
        gt_beams.append(jx["beam"])
    j=0
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        w=nx1-nx0; h=y1-ny0
        if w>20 or h<10 or ny0>be[1]: continue
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        bp=beam_probs(crop); hb=head_argmax(bp); gb=geo_beam(crop); ob=ot_beam(bp,gb)
        if j<len(gt_beams):
            gt=gt_beams[j]
            if hb==gt: hits["head"]+=1
            if gb==gt: hits["geo"]+=1
            if ob==gt: hits["ot"]+=1
            tot+=1
        j+=1
print(f"样本 {tot}")
for k in ("head","geo","ot"):
    print(f"  {k:5s}: {hits[k]} ({100*hits[k]/max(tot,1):.0f}%)")
