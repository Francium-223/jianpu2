# -*- coding: utf-8 -*-
"""端到端 修 digit=4: 用跨语料 真实4样本(fours) 重训 digit 头(知识保持: 从现有 heads 初始化)。
正样本: 模型判4的候选(p4 高的, 过滤掉明显的 #4/带杂点), 标 digit=4(索引3)。
其余: real_features.pkl 的非4 digit 保持不变。
输出 models/qwen-mt-v1/heads.pt (仅更新 digit 头)。"""
import os,sys,json,pickle; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset
from PIL import Image
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor

# 1) 收集 real4 图片(过滤: p4>=0.5, 且跳过明显升号#——用图像判断困难, 先粗筛)
fours=json.load(open("train-work/rest_corpus/pred4.json"))
print("候选4:",len(fours))
# 取 p4 排序前段; 但先看是否有特征缓存, 否则提取
imgs=[f["image"] for f in fours]
# 2) 提特征
if os.path.exists("train-data-atoms-v4-json/real4_feats.pkl"):
    r4=pickle.load(open("train-data-atoms-v4-json/real4_feats.pkl","rb"))
    z4=[r["feat"] for r in r4]
    print("用缓存 real4特征:",len(z4))
else:
    proc=get_processor(); visual=load_qwen_visual()
    z4=[]
    for ip in imgs:
        img=_crop_content(Image.open(ip).convert("RGB")); enc=proc(img,return_tensors="pt")
        p,g=enc["pixel_values"],enc["image_grid_thw"]
        with torch.no_grad():
            f=visual(p.cuda(),g.cuda()).mean(dim=0).float().cpu().numpy()
        z4.append(f)
    pickle.dump([{"feat":f} for f in z4], open("train-data-atoms-v4-json/real4_feats.pkl","wb"))
    print("提特征 real4:",len(z4))

# 3) 合并训练集: 真实4(索引3) + real_features 非4
old=pickle.load(open("train-data-atoms-v4-json/real_features.pkl","rb"))
X=[];y=[]
for f in z4: X.append(f); y.append(3)
for r in old:
    if "digit" in r["label"]:
        dv=r["label"]["digit"]
        if len(dv)!=9: continue
        d=int(np.argmax(dv))
        if d!=3: X.append(r["feat"]); y.append(d)
X=np.array(X,dtype=np.float32); y=np.array(y,dtype=np.int64)
print("训练集: 真实4=%d 其它=%d 总=%d 占比=%.1f%%"%(len(z4),len(X)-len(z4),len(X),100*len(z4)/len(X)))

# 4) 从现有 heads 初始化 digit 头, 低LR微调
heads=torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")
model=nn.Linear(2048,9)
_dh={}
for k,v in heads.items():
    if k.startswith("digit."): _dh[k.replace("digit.","")]=v
try:
    model.load_state_dict(_dh); print("从现有 heads 初始化 digit 头")
except Exception as ex:
    print("初始化失败, 随机:",ex)
gpu=torch.cuda.is_available()
if gpu: model=model.cuda()
Xt,yt=torch.tensor(X),torch.tensor(y)
dl=DataLoader(TensorDataset(Xt,yt),batch_size=64,shuffle=True,num_workers=0)
opt=torch.optim.AdamW(model.parameters(),lr=6e-5,weight_decay=1e-5)
lossf=nn.CrossEntropyLoss()
for ep in range(15):
    model.train(); tot=0;nb=0
    for xb,yb in dl:
        if gpu: xb,yb=xb.cuda(),yb.cuda()
        l=lossf(model(xb),yb); opt.zero_grad(); l.backward(); opt.step(); tot+=l.item();nb+=1
    if (ep+1)%5==0 or ep==14: print(f"epoch{ep+1}: loss{tot/nb:.3f}")
heads["digit.weight"]=model.weight.data.cpu(); heads["digit.bias"]=model.bias.data.cpu()
torch.save(heads,"models/qwen-mt-v1/heads.pt")
print("digit 头已更新(修4) -> heads.pt")
