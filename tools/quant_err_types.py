# -*- coding: utf-8 -*-
"""量化 spring 当前输出里的错误构成: 统计 与GT逐位比对时, 有多少 digit错 / beam错 / octave错。
判断 修 s/q、修 4 各能提升多少。"""
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
OUT=load("train-work/spring_verify_final_out.txt")
jo=[t2j(x) for x in OUT]; jg=[t2j(x) for x in GT]
# 对齐(digit+octave做对齐基准)
sm=SequenceMatcher(None,[(j["digit"],j["low"],len(j["voice"])) for j in jo],[(j["digit"],j["low"],len(j["voice"])) for j in jg])
digit_err=beam_err=oct_err=0
for tag,i1,i2,j1,j2 in sm.get_opcodes():
    if tag=="replace":
        for k in range(max(i2-i1,j2-j1)):
            oi=i1+k if i1+k<i2 else None; gj=j1+k if j1+k<j2 else None
            if oi is not None and gj is not None:
                o,g=jo[oi],jg[gj]
                if o["digit"]!=g["digit"]: digit_err+=1
                if o["beam"]!=g["beam"]: beam_err+=1
                if (o["low"],len(o["voice"]))!=(g["low"],len(g["voice"])): oct_err+=1
print(f"逐位对齐统计(仅对齐到位的替换位):")
print(f"  digit 错: {digit_err}")
print(f"  beam 错: {beam_err}")
print(f"  octave 错: {oct_err}")
print(f"\n说明: 这些是'对齐到位'的错误; 若补 s/q(beam)、补4(digit) 能修, 直接对应上列数字.")
