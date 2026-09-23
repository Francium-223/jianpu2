# -*- coding: utf-8 -*-
"""把 81状态输出 与 权威GT 逐位并排, 并标注每个 token 属于原谱哪一行(带)/大致歌词区,
便于我对照原图位置判断对错。"""
import re
from difflib import SequenceMatcher
from token_json import token_to_json as t2j
def load(file):
    t=open(file,encoding="utf-8",errors="replace").read()
    m=re.search(r"\d+\s*音\s*\n?\s*(.+)$",t,re.S)
    return [x for x in (m.group(1) if m else t).split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x)]
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtl=[l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l)]
gs=" ".join(gtl).replace("("," ").replace(")"," ")
GT=[x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x) or x=="-"]
OUT=load("train-work/spring_confirm_out.txt")
def key(t):
    j=t2j(t); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
jo=[key(x) for x in OUT]; jg=[key(x) for x in GT]
sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg])
ok=0; res=[]
for tag,i1,i2,j1,j2 in sm.get_opcodes():
    if tag=="equal":
        for k in range(i2-i1): res.append((OUT[i1+k],GT[j1+k],"OK")); ok+=1
    elif tag=="replace":
        for k in range(max(i2-i1,j2-j1)):
            oi=i1+k if i1+k<i2 else None; gj=j1+k if j1+k<j2 else None
            if oi is not None and gj is not None: res.append((OUT[oi],GT[gj],"X"))
            elif oi is not None: res.append((OUT[oi],"--","+"))
            else: res.append(("--",GT[gj],"-"))
    elif tag=="delete":
        for k in range(i2-i1): res.append((OUT[i1+k],"--","+"))
    elif tag=="insert":
        for k in range(j2-j1): res.append(("--",GT[j1+k],"-"))
print(f"输出 {len(OUT)} | GT {len(GT)} | 对齐OK {ok}\n")
# 每 10 位置打一个带行标签(这里不带, 直接序号), 用 歌词行 大致分批
for i,(o,g,m) in enumerate(res):
    mark={"OK":"✓","X":"✗","+":"多","-":"少"}[m]
    eq="  " if o==g else "**"
    print(f"{i:3d} [{mark}] 输出[{o or '--':8s}] GT[{g or '--':8s}] {eq}")
