# -*- coding: utf-8 -*-
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pipeline as P
import re
from difflib import SequenceMatcher
from token_json import token_to_json as t2j
toks,meta=P.transcribe("images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg")
def key(t):
    j=t2j(t); return (j["digit"],j["low"],len(j["voice"]),j["beam"],j["dotted"],j["accidental"])
gts=[l.strip() for l in open("train-work/gt/春天在哪里.txt",encoding="utf-8").read().splitlines()]
gtl=[l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]",l)]
gs=" ".join(gtl).replace("("," ").replace(")"," ")
GT=[x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x) or x=="-"]
jo=[key(x) for x in toks]; jg=[key(x) for x in GT]
sm=SequenceMatcher(None,[(k[0],k[1],k[2]) for k in jo],[(k[0],k[1],k[2]) for k in jg]); ok=0
for tag,i1,i2,j1,j2 in sm.get_opcodes():
    if tag=="equal": ok+=i2-i1
print(f"spring OK={ok} 音{len(toks)}")
