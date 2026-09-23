# -*- coding: utf-8 -*-
"""原子+真实 混合重训 6 头 (Qwen3-2B 特征). 合并 features.pkl(原子) + real_features.pkl(真实).
输出 models/qwen-mt-v1/heads.pt. 类均衡 + 验证把关."""
import os,sys,pickle; sys.path.insert(0,"tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, torch, torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset
import random; random.seed(0); np.random.seed(0); torch.manual_seed(0)
if torch.cuda.is_available(): torch.cuda.manual_seed_all(0)
DIM_N={"digit":9,"beam":5,"low":4,"voice":4,"dotted":2,"accidental":3}
def load_feats(p):
    return pickle.load(open(p,"rb"))
atom=load_feats("train-data-atoms-v4-json/features.pkl")
real=load_feats("train-data-atoms-v4-json/real_features.pkl")
allf=atom+real
print("总特征", len(allf), "原子", len(atom), "真实", len(real))
# 按 label 的每个头做 one-hot target
import numpy as np
X=np.array([f["feat"] for f in allf],dtype=np.float32)
def make_y(lst,key):
    dims=len(lst[0]["label"][key]); y=np.zeros((len(lst),dims),dtype=np.float32)
    for i,f in enumerate(lst): y[i]=f["label"][key]
    return y
Y={k:make_y(allf,k) for k in DIM_N}
# 切分
rng=np.random.RandomState(0); perm=rng.permutation(len(X)); nv=int(0.15*len(X)); va,tr=perm[:nv],perm[nv:]
model=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in DIM_N.items()})
gpu=torch.cuda.is_available()
if gpu: model=model.cuda()
xt=torch.tensor(X[tr])
if gpu: xt=xt.cuda()
yt={k:torch.tensor(Y[k][tr]) for k in DIM_N}
yv={k:torch.tensor(Y[k][va]) for k in DIM_N}
if gpu:
    for k in DIM_N: yt[k]=yt[k].cuda(); yv[k]=yv[k].cuda()
dl=DataLoader(TensorDataset(xt, yt["digit"], yt["beam"], yt["low"], yt["voice"], yt["dotted"], yt["accidental"]),batch_size=64,shuffle=True,num_workers=0,generator=torch.Generator().manual_seed(0))
opt=torch.optim.AdamW(model.parameters(),lr=1e-3,weight_decay=1e-5)
lossf=nn.CrossEntropyLoss()
def eval_acc():
    model.eval()
    with torch.no_grad():
        p={k:model[k](xt).argmax(dim=1) for k in DIM_N}
        acc={k:(p[k]==yt[k].argmax(dim=1)).float().mean().item() for k in DIM_N}
    return acc
best=None
for ep in range(40):
    model.train(); tot=0;nb=0
    for (xb, ld, lb, ll, lv, ldo, la) in dl:
        lab={"digit":ld,"beam":lb,"low":ll,"voice":lv,"dotted":ldo,"accidental":la}
        out={k:model[k](xb) for k in DIM_N}
        loss=None
        for k in DIM_N:
            l=lossf(out[k],lab[k].argmax(dim=1)); loss=l if loss is None else loss+l
        opt.zero_grad(); loss.backward(); opt.step(); tot+=loss.item(); nb+=1
    acc=eval_acc()
    avg=sum(acc.values())/len(acc)
    if best is None or avg>best[0]:
        best=(avg,ep); torch.save({k:(model[k].weight.data.cpu(),model[k].bias.data.cpu()) for k in DIM_N},"models/qwen-mt-v1/heads_mix_tmp.pt")
    if (ep+1)%8==0 or ep==39: print(f"ep{ep+1} loss{tot/nb:.2f} 平均准确{avg:.3f} best{best[0]:.3f}@ep{best[1]}")
mf={k: (torch.load("models/qwen-mt-v1/heads_mix_tmp.pt",map_location="cpu")[k]) for k in DIM_N}
for k in DIM_N:
    model[k].weight.data=mf[k][0].cpu(); model[k].bias.data=mf[k][1].cpu()
torch.save({k:(model[k].weight.data.cpu(),model[k].bias.data.cpu()) for k in DIM_N},"models/qwen-mt-v1/heads.pt")
print("混合重训完成 -> heads.pt")
