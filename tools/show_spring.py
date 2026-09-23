# -*- coding: utf-8 -*-
"""spring(春天在哪里) 生产路径转写 + 与 GT 对齐, 输出 token 序列 + 标注图。"""
import os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from difflib import SequenceMatcher
import jp_transcribe as JP
from token_json import token_to_json, normalize_tokens

IMG = "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
OUT = "train-work/spring_final.png"
toks, meta = JP.render(IMG, OUT)
# 我方输出现在会带连线标记(~ 和括号), 评测前先规范化掉, 否则和 GT 对不齐
toks = normalize_tokens(toks, merge_ties=False)

gts = [l.strip() for l in open("train-work/gt/春天在哪里.txt", encoding="utf-8").read().splitlines()]
gtl = [l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]", l)]
gs = " ".join(gtl).replace("(", " ").replace(")", " ")
GT = [x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$", x) or x == "-"]

def key(t):
    j = token_to_json(t)
    return (j["digit"], j["low"], len(j["voice"]), j["beam"], j["dotted"], j["accidental"])

sm = SequenceMatcher(None, [key(x) for x in toks], [key(x) for x in GT])
ok = sum(i2 - i1 for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag == "equal")
dot = sum(1 for t in toks if "." in t)
x = sum(1 for t in toks if "x" in t)
print(f"=== 春天在哪里 ===")
print(f"转写 {len(toks)} token (GT {len(GT)})   OK={ok}  附点{dot}  x{x}")
print(f"标注图: {OUT}\n")
print("转写序列:")
print(" ".join(toks))
print("\nGT 序列:")
print(" ".join(GT))
print("\n差异 (转写 vs GT):")
for tag, i1, i2, j1, j2 in sm.get_opcodes():
    if tag != "equal":
        print(f"  [{tag}] 转写[{i1}:{i2}]={' '.join(toks[i1:i2])!r}  GT[{j1}:{j2}]={' '.join(GT[j1:j2])!r}")
