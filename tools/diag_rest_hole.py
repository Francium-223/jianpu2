# -*- coding: utf-8 -*-
"""对 预测为0 的块, 用 洞(内部闭合) + 圆度 判别真rest0 vs 裸数字假0。
打印每个: 洞数, 宽高, 是否近似环形(0椭圆)。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image
from collections import deque
import transcribe as T
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor
import transcribe_qwen as Q

heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in {"digit":9}.items()})
heads.load_state_dict({k:v for k,v in torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu").items() if k.startswith("digit")})
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda"); heads.eval()
def dig(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        dp=torch.softmax(heads["digit"](f.unsqueeze(0)),-1)[0]
    return int(dp.argmax()), float(dp[7])

def holes_of(mask):
    H,W=mask.shape
    bg=np.zeros((H,W),np.uint8); q=deque()
    for y in range(H):
        for x in (0,W-1):
            if not mask[y,x] and bg[y,x]==0: bg[y,x]=1;q.append((y,x))
    for y in (0,H-1):
        for x in range(W):
            if not mask[y,x] and bg[y,x]==0: bg[y,x]=1;q.append((y,x))
    while q:
        y,x=q.popleft()
        for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
            ny,nx=y+dy,x+dx
            if 0<=ny<H and 0<=nx<W and not mask[ny,nx] and bg[ny,nx]==0:
                bg[ny,nx]=1;q.append((ny,nx))
    nb=0; seen=np.zeros((H,W),np.uint8)
    for y in range(H):
        for x in range(W):
            if not mask[y,x] and bg[y,x]==0 and seen[y,x]==0:
                nb+=1;q=deque([(y,x)]);seen[y,x]=1
                while q:
                    yy,xx=q.popleft()
                    for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
                        ny,nx=yy+dy,xx+dx
                        if 0<=ny<H and 0<=nx<W and not mask[ny,nx] and bg[ny,nx]==0 and seen[ny,nx]==0:
                            seen[ny,nx]=1;q.append((ny,nx))
    return nb

F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
# 逐带收集数字块, 对判0的算洞/圆度
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
        m=crop<170; Hh,Ww=m.shape
        if Hh<8 or Ww<4: continue
        d,p0=dig(crop)
        if d==7:  # 判为0
            hoop=holes_of(m)
            # 圆度: 面积/外接矩形, 及宽高比
            area=int(m.sum()); bbox=Hh*Ww
            fill=area/max(bbox,1)
            aspect=Ww/max(Hh,1)
            is_ring = hoop>=1 and 0.5<=aspect<=1.8
            print(f"带{band} x{nx0} w{Ww} h{Hh} p0={p0:.2f} 洞={hoop} 填充={fill:.2f} 宽高比={aspect:.2f} {'<环状rest0' if is_ring else '(非闭环)'}")
