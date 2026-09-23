# -*- coding: utf-8 -*-
"""重建 digit 头(均衡): 用 atom features + real_features + real4 + rest0 特征, 每类按逆频率加权,
避免 4/0 过度主导(上次 4 不加权导致 4 泛滥, OK 81->72)。类权重限制在 [0.5, 3.0] 防止反失衡。
输出 models/qwen-mt-v1/digit_head.pt 并并入 heads.pt。"""
import os,sys,pickle; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, torch, torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

# 收集数字标签样本
def load_digit_feats(pkl, label_key="label"):
    feats=pickle.load(open(pkl,"rb"))
    X=[];y=[]
    for r in feats:
        lb=r.get(label_key)
        if isinstance(lb,dict) and "digit" in lb:
            dv=lb["digit"]
            if len(dv)==9: X.append(r["feat"]); y.append(int(np.argmax(dv)))
    return X,y
X=[];y=[]
# atom 基础(有所有数字, 均衡)
ax,ay=load_digit_feats("train-data-atoms-v4-json/features.pkl")
X+=ax; y+=ay
# real 特征
rx,ry=load_digit_feats("train-data-atoms-v4-json/real_features.pkl")
X+=rx; y+=ry
# real4(索引3)
r4=pickle.load(open("train-data-atoms-v4-json/real4_feats.pkl","rb"))
for r in r4: X.append(r["feat"]); y.append(3)
# rest0(索引7)
r0=pickle.load(open("train-data-atoms-v4-json/rest0_feats.pkl","rb"))
for r in r0: X.append(r["feat"]); y.append(7)
X=np.array(X,dtype=np.float32); y=np.array(y,dtype=np.int64)
print("总样本",len(X),"各类分布:",{i:int((y==i).sum()) for i in range(9)})
# 类权重 = 逆频率, 截断
cnt=np.bincount(y,minlength=9); n=len(y)
w=(n/(9*np.maximum(cnt,1))).clip(0.5,3.0)
print("类权重:",np.round(w,2).tolist())
cw=torch.tensor(w,dtype=torch.float32)
gpu=torch.cuda.is_available()
if gpu: cw=cw.cuda()
# 训练/验证切分
rng=np.random.RandomState(1); perm=rng.permutation(len(y)); nv=int(0.15*len(y))
va,tr=perm[:nv],perm[nv:]
Xt,yt=torch.tensor(X[tr]),torch.tensor(y[tr]); Xv,yv=torch.tensor(X[va]),torch.tensor(y[va])
if gpu: Xt,yt,Xv,yv=Xt.cuda(),yt.cuda(),Xv.cuda(),yv.cuda()
dl=DataLoader(TensorDataset(Xt,yt),batch_size=128,shuffle=True,num_workers=0)
def ev():
    model.eval()
    with torch.no_grad():
        p=torch.softmax(model(Xv),-1).cpu().numpy(); pred=p.argmax(1); yvn=yv.cpu().numpy()
    return (pred==yvn).mean()
model=nn.Linear(2048,9)
# 从现有 heads 的 digit 初始化(保留已有知识)
heads=torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")
if "digit.weight" in heads:
    _dh={"weight":heads["digit.weight"],"bias":heads["digit.bias"]}
    try: model.load_state_dict(_dh); print("从现有 heads 初始化")
    except Exception as e: print("初始化失败:",e)
if gpu: model=model.cuda()
opt=torch.optim.AdamW(model.parameters(),lr=4e-5,weight_decay=1e-6)
lossf=nn.CrossEntropyLoss(weight=cw)
best=None
for ep in range(20):
    model.train(); tot=0;nb=0
    for xb,yb in dl:
        l=lossf(model(xb),yb); opt.zero_grad(); l.backward(); opt.step(); tot+=l.item();nb+=1
    acc=ev()
    if best is None or acc>best[0]:
        best=(acc,ep)
        torch.save({"weight":model.weight.data.cpu(),"bias":model.bias.data.cpu()},"models/qwen-mt-v1/digit_head.pt")
    if (ep+1)%4==0 or ep==19: print(f"ep{ep+1}: loss{tot/nb:.3f} valacc{acc:.3f} best{best[0]:.3f}@ep{best[1]}")
heads["digit.weight"]=torch.load("models/qwen-mt-v1/digit_head.pt",map_location="cpu")["weight"]
heads["digit.bias"]=torch.load("models/qwen-mt-v1/digit_head.pt",map_location="cpu")["bias"]
torch.save(heads,"models/qwen-mt-v1/heads.pt")
print("digit 头已均衡重建 -> heads.pt")
