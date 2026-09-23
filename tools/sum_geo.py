# -*- coding: utf-8 -*-
"""对比 上一版(仅beam geo) vs 本版(beam+low+voice+dotted geo) 的 GT 对齐。"""
import re,sys
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
def key(tok):
    j=token_to_json(tok); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
def report(name,file):
    OUT=load(file); jo=[key(x) for x in OUT]; jg=[key(x) for x in GT]
    sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg])
    ok=dif=dl=ins=0
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        if tag=="equal": ok+=i2-i1
        elif tag=="replace": dif+=max(i2-i1,j2-j1)
        elif tag=="delete": dl+=i2-i1
        elif tag=="insert": ins+=j2-j1
    print(f"{name:24s}: OK={ok:3d} 错{dif:3d} 多{dl:2d} 缺{ins:2d}")
for n,f in [("仅beam geo(上版)","train-work/spring_bound_out.txt"),("beam+low+voice+dotted geo","train-work/spring_geo_out.txt"),("基(cropfix)","train-work/spring_cropfix_out.txt")]:
    report(n,f)
