# -*- coding: utf-8 -*-
import re
from difflib import SequenceMatcher
from token_json import token_to_json
def load(file):
    t=open(file,encoding="utf-8",errors="replace").read()
    m=re.search(r"\d+\s*音\s*\n?\s*(.+)$",t,re.S)
    return [x for x in (m.group(1) if m else t).split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x)]
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtl=[l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l)]
gs=" ".join(gtl).replace("("," ").replace(")"," ")
GT=[x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x) or x=="-"]
def key(t):
    j=token_to_json(t); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
def report(name,file):
    OUT=load(file); jo=[key(x) for x in OUT]; jg=[key(x) for x in GT]
    sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg])
    ok=dif=dl=ins=0
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        if tag=="equal": ok+=i2-i1
        elif tag=="replace": dif+=max(i2-i1,j2-j1)
        elif tag=="delete": dl+=i2-i1
        elif tag=="insert": ins+=j2-j1
    jo0=[k[0] for k in jo]; jg0=[k[0] for k in jg]; sm0=SequenceMatcher(None,jo0,jg0)
    r0=r0m=0
    for tag,i1,i2,j1,j2 in sm0.get_opcodes():
        if tag=="equal":
            for k in range(i2-i1):
                if jg0[j1+k]=="0": r0+=1
        elif tag=="replace":
            for k in range(max(i2-i1,j2-j1)):
                oi=i1+k if i1+k<i2 else None; gj=j1+k if j1+k<j2 else None
                if oi is not None and gj is not None and jg0[gj]=="0": r0m+=1
    print(f"{name:36s}: OK={ok:3d} 错{dif:3d} 多{dl:2d} 缺{ins:2d} | rest0对{r0} 误{r0m}")
for n,f in [("最初基(cropfix)","train-work/spring_cropfix_out.txt"),("rest0+0.60门","train-work/spring_lowclamp_out.txt"),("rest0+0.75门+lowclamp(最终)","train-work/spring_final3_out.txt")]:
    report(n,f)
