# -*- coding: utf-8 -*-
"""检查各 '假0' 位置(带,x): 裁剪是否真是 rest0 椭圆, 还是数字被误判0。
打印 数字头部 top3 + 洞数 + 宽高。"""
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
DIG=["1","2","3","4","5","6","7","0","x"]
def dp(crop):
    cimg=_crop_content(Image.fromarray(crop).convert("RGB")); enc=proc(cimg,return_tensors="pt")
    p,g=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
        return torch.softmax(heads["digit"](f.unsqueeze(0)),-1)[0].cpu().numpy()
def hole(mask):
    H,W=mask.shape; bg=np.zeros((H,W),np.uint8); q=deque()
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
            if 0<=ny<H and 0<=nx<W and not mask[ny,nx] and bg[ny,nx]==0: bg[ny,nx]=1;q.append((ny,nx))
    nb=0;seen=np.zeros((H,W),np.uint8)
    for y in range(H):
        for x in range(W):
            if not mask[y,x] and bg[y,x]==0 and seen[y,x]==0:
                nb+=1;q=deque([(y,x)]);seen[y,x]=1
                while q:
                    yy,xx=q.popleft()
                    for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
                        ny,nx=yy+dy,xx+dx
                        if 0<=ny<H and 0<=nx<W and not mask[ny,nx] and bg[ny,nx]==0 and seen[ny,nx]==0: seen[ny,nx]=1;q.append((ny,nx))
    return nb
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
targets={1:[452],3:[325],5:[77,427],7:[583,662]}
for band,xs in targets.items():
    s,e=T.fine_rows(content,T.ROW_GAP)[band]; sub=content[s:e+1]
    comps=T.components(sub); thin=[c for c in comps if c[4]<=5 and c[5]>=10]
    be=None
    if thin:
        hmax=max(c[5] for c in thin); bars=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
        if len(bars)>=T.BAR_THR: be=(min(b[1] for b in bars),max(b[3] for b in bars))
    row_gray=arr[s:e+1]
    for (nx0,nx1,ny0,ny1) in T.crop_note_regions(sub):
        if not any(abs(nx0-x)<8 for x in xs): continue
        y1=min(ny1,be[1]) if (be and ny0<=be[1]+2) else ny1
        crop=Q.bound_to_note_row(row_gray,nx0,nx1,ny0,ny1,be)
        if crop is None or crop.size==0: continue
        p=dp(crop); d=int(p.argmax()); m=crop<170; Hh,Ww=m.shape
        top3=np.argsort(-p)[:3]
        print(f"带{band} x{nx0} {Ww}x{Hh} 洞={hole(m)} 预测={DIG[d]} top3={[(DIG[int(t)],round(float(p[t]),2)) for t in top3]}")
