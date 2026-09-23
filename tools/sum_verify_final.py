# -*- coding: utf-8 -*-
"""最终: 对比 关键里程碑, 并确认两处目标修复在最终输出已消除。
(1) 无 q,,1 / q,,,3 (low-clamp 生效)  (2) 裸3 不再被当0 (0.75门生效)."""
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
    jo0=[k[0] for k in jo]; jg0=[k[0] for k in jg]; sm0=SequenceMatcher(None,jo0,jg0)
    r0=0
    for tag,i1,i2,j1,j2 in sm0.get_opcodes():
        if tag=="equal":
            for k in range(i2-i1):
                if jg0[j1+k]=="0": r0+=1
    bad1=sum(1 for x in OUT if x.count(",")>=2)
    print(f"{name:38s}: OK={ok:3d} rest0对={r0} 含>=2逗号(异常low)的token={bad1}")
for n,f in [("最初基(cropfix)","train-work/spring_cropfix_out.txt"),("rest0+0.60门+lowclamp","train-work/spring_lowclamp_out.txt"),("最终(0.75门+lowclamp)","train-work/spring_verify_final_out.txt")]:
    report(n,f)
print("\n目标1检查: 最终输出无 q,,1 / q,,,3? ", "q,,1" not in load("train-work/spring_verify_final_out.txt") or "q,,,3" not in load("train-work/spring_verify_final_out.txt"))
