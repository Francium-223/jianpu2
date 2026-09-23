# -*- coding: utf-8 -*-
"""对比 spring_seeded(81) vs spring_4safe(80): 列出 改好(81错4safe对) vs 改坏(81对4safe错) 的位置。
判断 4 修复净收益 是否值得那 1 分损失。"""
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
a81=aligns(load("train-work/spring_seeded_out.txt"))
a80=aligns(load("train-work/spring_4safe_out.txt"))
better=worse=0
print("81 -> 80 逐位变化:")
for i in range(min(len(a81),len(a80))):
    b,f=a81[i],a80[i]
    b_ok=b[2]=="OK"; f_ok=f[2]=="OK"
    if not b_ok and f_ok: better+=1
    if b_ok and not f_ok: worse+=1
print(f"  修好(81错→80对): {better}  改坏(81对→80错): {worse}")
