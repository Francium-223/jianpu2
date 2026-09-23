# -*- coding: utf-8 -*-
"""用 spring(有 GT) 检验 CV 门是否误杀真音符: 对比 OK 与音符数。"""
import os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from difflib import SequenceMatcher
import jp_transcribe as JP
from token_json import token_to_json

IMG = "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"

toks, meta = JP.transcribe(IMG)

def key(t):
    j = token_to_json(t)
    return (j["digit"], j["low"], len(j["voice"]), j["beam"], j["dotted"], j["accidental"])

gts = [l.strip() for l in open("train-work/gt/春天在哪里.txt", encoding="utf-8").read().splitlines()]
gtl = [l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]", l)]
gs = " ".join(gtl).replace("(", " ").replace(")", " ")
GT = [x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$", x) or x == "-"]
sm = SequenceMatcher(None, [key(x) for x in toks], [key(x) for x in GT])
ok = sum(i2 - i1 for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag == "equal")
dot = sum(1 for t in toks if "." in t)
x = sum(1 for t in toks if "x" in t)
print(f"spring: 音{len(toks)} OK={ok}/{len(GT)} 附点{dot} x{x}")
