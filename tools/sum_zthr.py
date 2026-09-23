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
    ok=0
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        if tag=="equal": ok+=i2-i1
    # rest0
    jo0=[k[0] for k in jo]; jg0=[k[0] for k in jg]; sm0=SequenceMatcher(None,jo0,jg0)
    r0=0
    for tag,i1,i2,j1,j2 in sm0.get_opcodes():
        if tag=="equal":
            for k in range(i2-i1):
                if jg0[j1+k]=="0": r0+=1
    # 输出中0的个数(假0倾向)
    nout0=sum(1 for k in jo if k[0]=="0")
    print(f"{name:22s}: OK={ok:3d}  rest0对={r0}  输出0的个数={nout0}")
for n,f in [("门槛0.60(改前)","train-work/spring_lowclamp_out.txt"),("门槛0.70","train-work/spring_z0.70_out.txt"),("门槛0.75","train-work/spring_z0.75_out.txt"),("门槛0.80","train-work/spring_z0.80_out.txt")]:
    report(n,f)
