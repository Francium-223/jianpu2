# -*- coding: utf-8 -*-
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
def rpt(n,f):
    OUT=load(f); jo=[key(x) for x in OUT]; jg=[key(x) for x in GT]
    sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg]); ok=0
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        if tag=="equal": ok+=i2-i1
    print(f"{n:20s}: {len(OUT)}音 OK={ok}")
rpt("83基线","train-work/spring_src_out.txt")
rpt("crop修复后","train-work/spring_aft_fix.txt")
rpt("附点收纳后","train-work/spring_dot_out.txt")
rpt("附点放宽后","train-work/spring_dotw_out.txt")
rpt("容易杠判定","train-work/spring_easy_out.txt")
rpt("is_note=0.42","train-work/spring_042.txt")
rpt("默认0.42","train-work/spring_def.txt")
rpt("geo-low覆盖","train-work/spring_geolow.txt")
