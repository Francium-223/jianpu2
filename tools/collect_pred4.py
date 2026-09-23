# -*- coding: utf-8 -*-
"""跨语料收集 被模型判为 4 的真实裁剪候选(用当前digit头), 按置信排序, 输出蒙太奇供肉眼确认。
用于补 digit=4 真实样本。"""
import os,sys,json; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('TOKENIZERS_PARALLELISM','false')
import numpy as np, torch, torch.nn as nn
from PIL import Image, ImageDraw, ImageFont
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor
heads=nn.ModuleDict({k:nn.Linear(2048,n) for k,n in {"digit":9}.items()})
heads.load_state_dict({k:v for k,v in torch.load("models/qwen-mt-v1/heads.pt",map_location="cpu").items() if k.startswith("digit")})
visual=load_qwen_visual(); proc=get_processor(); heads=heads.to("cuda"); heads.eval()
DIG=["1","2","3","4","5","6","7","0","x"]
cands=json.load(open("train-work/rest_corpus/manifest.json"))
fours=[]
for c in cands:
    try:
        img=_crop_content(Image.open(c["image"]).convert("RGB"))
        enc=proc(img,return_tensors="pt"); p,g=enc["pixel_values"],enc["image_grid_thw"]
        with torch.no_grad():
            f=visual(p.cuda(),g.cuda()).mean(dim=0).float()
            dp=torch.softmax(heads["digit"](f.unsqueeze(0)),-1)[0].cpu().numpy()
        if int(dp.argmax())==3:  # DIGIT[3]="4"
            fours.append({"image":c["image"],"p4":float(dp[3])})
    except Exception as e:
        pass
fours.sort(key=lambda x:-x["p4"])
json.dump(fours, open("train-work/rest_corpus/pred4.json","w"))
print("模型判为4的候选:",len(fours))
sel=fours[:100]
font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",9)
cw=72;ch=84;cols=10;rows=(len(sel)+cols-1)//cols
cv=Image.new("RGB",(cols*cw,rows*ch),(255,255,255)); dr=ImageDraw.Draw(cv)
for i,v in enumerate(sel):
    img=_crop_content(Image.open(v["image"]).convert("L")); img=img.resize((cw-12,ch-20),Image.LANCZOS)
    r,c=divmod(i,cols); cv.paste(img,(c*cw+6,r*ch+16)); dr.text((c*cw+2,r*ch+2),f"{v['p4']:.2f}",fill=(0,0,0),font=font)
cv.save("train-work/split_demo/corpus_pred4.png"); print("corpus_pred4.png",len(sel))
