# -*- coding: utf-8 -*-
"""端到端 rest(0) 修复: 提取真实 rest0 特征 -> 与现有非0特征合并 -> 重训 digit 头。
只重训 digit 头(finetune), 其它头(beam/low/voice/dotted/acc) 保留原值。
输出 models/qwen-mt-v1/heads.pt。
"""
import os, sys, json, pickle; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ['TOKENIZERS_PARALLELISM']='false'
import numpy as np, torch, torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset
from transformers import AutoModel, AutoImageProcessor
from PIL import Image
from note_prep import _crop_content

# ---- 1. 收集 rest0 正样本 ----
rest0_imgs=[]
for v in json.load(open("train-work/rest_corpus/pred0_all.json")):
    rest0_imgs.append(v["image"])
for m in json.load(open("train-work/real_rest_v4/manifest.json")):
    if m["band"]!=3:
        rest0_imgs.append(m["image"])
print("rest0 正样本:", len(rest0_imgs))

# ---- 2. 提取 rest0 特征 ----
proc=AutoImageProcessor.from_pretrained("models/Qwen2.5-VL-3B-Instruct",trust_remote_code=True)
proc.size={"shortest_edge":224,"longest_edge":448}; proc.max_pixels=224*448*2
qwen=AutoModel.from_pretrained("models/Qwen2.5-VL-3B-Instruct",dtype=torch.bfloat16,trust_remote_code=True)
qwen.visual=qwen.visual.to("cuda"); visual=qwen.visual.eval(); qwen.visual=None
import gc; gc.collect()
zero_feats=[]
for img_p in rest0_imgs:
    img=_crop_content(Image.open(img_p).convert("RGB"))
    enc=proc(img,return_tensors="pt"); pixel,grid=enc["pixel_values"],enc["image_grid_thw"]
    with torch.no_grad():
        f=visual(pixel.to("cuda"),grid.to("cuda")).mean(dim=0).float().cpu().numpy()
    zero_feats.append(f)
    
# ---- 3. 合并训练集 ----
old=pickle.load(open("train-data-atoms-v4-json/real_features.pkl","rb"))
X=[]; y=[]
for f in zero_feats: X.append(f); y.append(7)
for r in old:
    if "digit" in r["label"]:
        dv=r["label"]["digit"]
        if len(dv)!=9: continue
        d=int(np.argmax(dv))
        if d!=7: X.append(r["feat"]); y.append(d)
X=np.array(X,dtype=np.float32); y=np.array(y,dtype=np.int64)
print("训练集: rest0正= %d, 其它digit= %d, 总= %d, rest0占比=%.1f%%" % (len(zero_feats), len(X)-len(zero_feats), len(X), 100*len(zero_feats)/len(X)))

# ---- 4. 重训 digit 头 ----
import random
random.seed(0); np.random.seed(0); torch.manual_seed(0)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(0)
gpu=torch.cuda.is_available()
model=nn.Linear(2048,9)
Xt=torch.tensor(X); yt=torch.tensor(y)
if gpu: model=model.to("cuda")
dl=DataLoader(TensorDataset(Xt,yt),batch_size=64,shuffle=True,num_workers=0,generator=torch.Generator().manual_seed(0))
opt=torch.optim.AdamW(model.parameters(),lr=2e-4,weight_decay=1e-4)
lossf=nn.CrossEntropyLoss()
for ep in range(25):
    model.train(); tot=0;nb=0
    for xb,yb in dl:
        if gpu: xb,yb=xb.cuda(),yb.cuda()
        l=lossf(model(xb),yb); opt.zero_grad(); l.backward(); opt.step()
        tot+=l.item();nb+=1
    if (ep+1)%5==0 or ep==24:
        print(f"epoch {ep+1}: loss {tot/nb:.4f}")
torch.save({"weight":model.weight.data.cpu(),"bias":model.bias.data.cpu()}, "models/qwen-mt-v1/digit_head.pt")
print("digit 头新权重 -> models/qwen-mt-v1/digit_head.pt")

# ---- 5. 合并回 heads.pt ----
heads=torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu")
dh=torch.load("models/qwen-mt-v1/digit_head.pt",map_location="cpu")
heads["digit.weight"]=dh["weight"]; heads["digit.bias"]=dh["bias"]
torch.save(heads,"models/qwen-mt-v1/heads.pt")
print("heads.pt 已更新 digit 头并保存.")
