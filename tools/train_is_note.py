# -*- coding: utf-8 -*-
"""修正版: 计算正确 AUC, 并扫描阈值, 给出 [歌词误判音符数, 音符漏检数] 曲线。
供挑选 IS_NOTE_THR。用法: py -3.13 tools/train_is_note.py --sweep
"""
import os, sys, pickle, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
feats = pickle.load(open("train-data-note-lyric/features.pkl", "rb"))
X = np.array([f["feat"] for f in feats], dtype=np.float32)
y = np.array([f["label"] for f in feats], dtype=np.float32)

class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.linear = nn.Linear(2048, 1)
    def forward(self, x):
        return self.linear(x)

ap = argparse.ArgumentParser(); ap.add_argument("--sweep", action="store_true"); a=ap.parse_args()

rng = np.random.RandomState(0)
perm = rng.permutation(len(y)); nval = int(0.2*len(y))
vi, ti = perm[:nval], perm[nval:]
Xt, yt = torch.tensor(X[ti]), torch.tensor(y[ti])
Xv, yv = torch.tensor(X[vi]), torch.tensor(y[vi])
gpu = torch.cuda.is_available()
model = Net()
if gpu: model = model.cuda(); Xt,yt=Xt.cuda(),yt.cuda(); Xv,yv=Xv.cuda(),yv.cuda()
opt = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=1e-4)
lossf = nn.BCEWithLogitsLoss()

def probs(Xa):
    model.eval()
    with torch.no_grad():
        return torch.sigmoid(model(Xa).squeeze(1)).cpu().numpy()

def auc(p, ya):
    ya = ya; npos=float(ya.sum()); nneg=float(len(ya)-npos)
    if npos==0 or nneg==0: return float('nan')
    order = np.argsort(p)            # 升序: 小p rank小
    ranks = np.empty(len(p)); ranks[order]=np.arange(1,len(p)+1)
    return (ranks[ya==1].sum()-npos*(npos+1)/2)/(npos*nneg)

for ep in range(12):
    model.train(); tot=0;nb=0
    for xb,yb in DataLoader(TensorDataset(Xt,yt),batch_size=512,shuffle=True,num_workers=0):
        if gpu: xb,yb=xb.cuda(),yb.cuda()
        loss = lossf(model(xb).squeeze(1), yb)
        opt.zero_grad(); loss.backward(); opt.step(); tot+=loss.item(); nb+=1

torch.save(model.state_dict(),"models/qwen-mt-v1/is_note.pt")
print("is_note 已存. 训练/验证 AUC:")
pv = probs(Xv); yvn = yv.cpu().numpy()
print(f"  val AUC={auc(pv,yvn):.4f}")
pt = probs(Xt); ytn = yt.cpu().numpy()
print(f"  train AUC={auc(pt,ytn):.4f}")

if a.sweep:
    print("\n阈值扫描 (val): thr | 歌词误判音符 | 音符漏检 | 保留音符")
    for thr in [0.20,0.30,0.35,0.40,0.45,0.50,0.55,0.60,0.65,0.70,0.75,0.80,0.85,0.90,0.95]:
        pred = (pv >= thr).astype(int)
        fp = ((pred==1)&(yvn==0)).sum()          # 歌词误判为音符
        fn = ((pred==0)&(yvn==1)).sum()          # 音符漏检
        tp = ((pred==1)&(yvn==1)).sum()
        print(f"  {thr:.2f} |  {fp:3d} |  {fn:3d} |  {tp}")
