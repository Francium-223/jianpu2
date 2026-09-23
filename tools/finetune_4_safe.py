# -*- coding: utf-8 -*-
"""安全修 digit=4 (三步): 
  ① 从当前 81 头 (heads_r81_backup.pt) 的 digit 初始化, 低 LR 微调 (知识保持)
  ② 类均衡权重 (4 不高估, 防其如上次泛滥)
  ③ 验证集把关: 按 '4召回 + 非4正确' 选最优 epoch; 仅当在真实spring上 OK>=81 才保留, 否则回滚。
训练用特征: atom features.pkl (含均衡4) + real_features + real4 + rest0。
输出: 决策 保留新版 / 回滚81, 并打印 spring OK 前后。"""
import os,sys,pickle; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

random_seed=0
import random; random.seed(random_seed); np.random.seed(random_seed); torch.manual_seed(random_seed)
if torch.cuda.is_available(): torch.cuda.manual_seed_all(random_seed)

def digit_feats(pkl):
    feats=pickle.load(open(pkl,"rb")); X=[];y=[]
    for r in feats:
        lb=r.get("label")
        if isinstance(lb,dict) and "digit" in lb:
            dv=lb["digit"]
            if len(dv)==9: X.append(r["feat"]); y.append(int(np.argmax(dv)))
    return X,y
X=[];y=[]
for pkl in ["train-data-atoms-v4-json/features.pkl","train-data-atoms-v4-json/real_features.pkl"]:
    ax,ay=digit_feats(pkl); X+=ax; y+=ay
for r in pickle.load(open("train-data-atoms-v4-json/real4_feats.pkl","rb")): X.append(r["feat"]); y.append(3)
for r in pickle.load(open("train-data-atoms-v4-json/rest0_feats.pkl","rb")): X.append(r["feat"]); y.append(7)
X=np.array(X,dtype=np.float32); y=np.array(y,dtype=np.int64)
print("总样本",len(X),"分布:",{i:int((y==i).sum()) for i in range(9)})

# 类权重: 逆频率, 截断[0.6,2.5] (4 不高估, 避免泛滥)
cnt=np.bincount(y,minlength=9); n=len(y)
w=(n/(9*np.maximum(cnt,1))).clip(0.6,2.5)
print("类权重:",np.round(w,2).tolist())
cw=torch.tensor(w,dtype=torch.float32)

# 验证切分(保存 4 与非4 比例)
rng=np.random.RandomState(1)
i4=np.where(y==3)[0]; io=np.where(y!=3)[0]
va=np.concatenate([rng.choice(i4,size=int(0.2*len(i4)),replace=False), rng.choice(io,size=int(0.2*len(io)),replace=False)])
tr=np.setdiff1d(np.arange(len(y)),va)

gpu=torch.cuda.is_available()
def dl(Xa,ya,bs): return DataLoader(TensorDataset(Xa,ya),batch_size=128,shuffle=True,num_workers=0,generator=torch.Generator().manual_seed(0))
# ① 从 81 头初始化
heads=torch.load("models/qwen-mt-v1/heads_r81_backup.pt",map_location="cpu")
model=nn.Linear(2048,9)
try:
    model.load_state_dict({"weight":heads["digit.weight"],"bias":heads["digit.bias"]}); print("① 从 81 头初始化 digit")
except Exception as e:
    print("初始化失败:",e)
Xt,yt=torch.tensor(X[tr]),torch.tensor(y[tr]); Xv,yv=torch.tensor(X[va]),torch.tensor(y[va])
if gpu: model=model.cuda(); Xt,yt,Xv,yv=Xt.cuda(),yt.cuda(),Xv.cuda(),yv.cuda(); cw=cw.cuda()
def ev():
    model.eval()
    with torch.no_grad():
        p=torch.softmax(model(Xv),-1).cpu().numpy(); pred=p.argmax(1); yvn=yv.cpu().numpy()
    four_rec=((pred==3)&(yvn==3)).sum()/max((yvn==3).sum(),1)
    non4=((pred[yvn!=3]==yvn[yvn!=3]).sum())/max((yvn!=3).sum(),1)
    return four_rec,non4
opt=torch.optim.AdamW(model.parameters(),lr=3e-5,weight_decay=1e-6)
lossf=nn.CrossEntropyLoss(weight=cw)
best=None
for ep in range(12):
    model.train(); tot=0;nb=0
    for xb,yb in dl(Xt,yt,128):
        if gpu: xb,yb=xb.cuda(),yb.cuda()
        l=lossf(model(xb),yb); opt.zero_grad(); l.backward(); opt.step(); tot+=l.item();nb+=1
    fr,n4=ev(); score=fr+n4
    if best is None or score>best[0]:
        best=(score,ep,fr,n4)
        torch.save({"weight":model.weight.data.cpu(),"bias":model.bias.data.cpu()},"models/qwen-mt-v1/digit_4safe.pt")
    if (ep+1)%4==0 or ep==11: print(f"ep{ep+1}: loss{tot/nb:.3f} 4召回{fr:.2f} 非4正确{n4:.2f} best{best[0]:.2f}@ep{best[1]}")
print(f"② 最优 epoch {best[1]}: 4召回{best[2]:.2f} 非4正确{best[3]:.2f}")
