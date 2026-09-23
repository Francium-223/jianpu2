# -*- coding: utf-8 -*-
"""评估 beam 头在 real_features.pkl 上的 每类召回(混淆矩阵), 看 s 是否因类不平衡被压。
若 s 召回显著低于 q, 说明 head 偏向 q, 可考虑重采样/加权。"""
import os,sys,pickle; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, torch, torch.nn as nn
rf=pickle.load(open('train-data-atoms-v4-json/real_features.pkl','rb'))
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in {"beam":5}.items()})
heads.load_state_dict({k:v for k,v in torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu").items() if k.startswith("beam")})
heads.eval()
# 取特征
X=[]; y=[]
for r in rf:
    if 'beam' not in r['label']: continue
    X.append(r['feat']); y.append(int(r['label']['beam'].index(1)))
X=np.array(X,dtype=np.float32); y=np.array(y)
# 训练/测试切分? 直接用原头在训练特征上(过拟合乐观, 仅看相对类召回)
import torch
Xt=torch.tensor(X)
with torch.no_grad():
    p=heads["beam"](Xt); pred=p.argmax(1).numpy()
names={0:"无",1:"q",2:"s",3:"d",4:"h"}
print("beam 头在 real_features 上的类召回(训练集内, 乐观):")
for c in range(5):
    mask=y==c
    if mask.sum()==0: continue
    rec=(pred[mask]==c).sum()/mask.sum()
    print(f"  类 {names[c]}: 样本 {mask.sum():4d}  召回 {rec*100:.0f}%")
# 混淆: s(2) 被误判成什么
for true,lbl in [(2,"s"),(1,"q")]:
    mask=y==true; wrong=pred[mask]
    from collections import Counter
    cnt=Counter(int(w) for w in wrong)
    print(f"  {lbl}({true}) 误判分布: { {names[k]:v for k,v in cnt.items()} }")
