# -*- coding: utf-8 -*-
"""只比"数字"(忽略八度/时值/附点), 看系统认数字准不准.
对比 全属性(1.4%) vs 仅数字 的匹配率. 判断 问题在"高低点/时值"还是"数字本身"。"""
import re
from difflib import SequenceMatcher
from token_json import token_to_json as t2j
def load_out(f):
    t=open(f,encoding="utf-8",errors="replace").read(); m=re.search(r"\d+\s*音\s*\n?\s*(.+)$",t,re.S)
    return [x for x in (m.group(1) if m else t).split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x)]
def load_gt(f):
    t=open(f,encoding="utf-8",errors="replace").read()
    lines=[l for l in t.splitlines() if re.search(r"[0-9x\-]",l) and not re.match(r"^\s*(title|MBID|type|copyright|OctavesAfter|1=|2/4|4/4|%|$)",l)]
    s=" ".join(lines)
    for ch in "(){}[]|~:": s=s.replace(ch," ")
    s=re.sub(r"[^0-9qsdh',\.x\- ]"," ",s)
    return [x for x in s.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$",x) or x=="-"]
def digit_only(tok):
    if tok=="-": return "-"
    m=re.match(r"^[a-z,']*([0-9x])",tok)
    return m.group(1) if m else "?"
def score(gt,out,mode):
    OT=load_out(out); GT=load_gt(gt)
    def k(t): return ("-",) if t=="-" else (t2j(t)["digit"],)
    ko=[k(x) for x in OT]; kg=[k(x) for x in GT]
    sm=SequenceMatcher(None,ko,kg); ok=sum(i2-i1 for tag,i1,i2,j1,j2 in sm.get_opcodes() if tag=="equal")
    return ok,len(OT),len(GT)
for n,g,o in [("兄弟抱一下","train-work/gt/兄弟抱一下.txt","train-work/time_out2.txt"),
              ("时间都去哪了","train-work/gt/时间都去哪了.txt","train-work/time_out3.txt")]:
    ok,ox,gx=score(g,o,"digit")
    print(f"{n}: 输出{ox} GT{gx} 仅数字匹配 OK={ok} 匹配率={100*ok/max(gx,1):.1f}%")
