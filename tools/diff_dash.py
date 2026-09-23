# -*- coding: utf-8 -*-
"""对比 81佳 vs dash修复(82): 逐位找出 修好(81错→82对) 与 改坏(81对→82错)。"""
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
def key(t):
    j=t2j(t); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
def aligns(OUT):
    jo=[key(x) for x in OUT]; jg=[key(x) for x in GT]
    sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg])
    res=[]
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        if tag=="equal":
            for k in range(i2-i1): res.append((OUT[i1+k],GT[j1+k],"OK"))
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
    return res
A=aligns(load("train-work/spring_confirm_out.txt"))
B=aligns(load("train-work/spring_dash_out.txt"))
better=worse=0
print("81 -> 82 (dash修复) 逐位:")
for i in range(min(len(A),len(B))):
    a,b=A[i],B[i]
    if a[2]!="OK" and b[2]=="OK": better+=1; print(f"  [{i}] 修好: 81[{a[0]}] -> 82[{b[0]}]  GT[{b[1]}]")
    if a[2]=="OK" and b[2]!="OK": worse+=1; print(f"  [{i}] 改坏: 81[{a[0]}] -> 82[{b[0]}]  GT[{a[1]}]")
print(f"\n修好 {better}  改坏 {worse}  净 {better-worse}")
