# -*- coding: utf-8 -*-
"""多谱验证: 用正式模块 jp_transcribe 跑 时间/兄弟/排排坐, 算 OK vs GT."""
import os, sys, re
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
from difflib import SequenceMatcher
from token_json import token_to_json
import jp_transcribe as JP

def parse_gt(f):
    lines = [l.strip() for l in open(f, encoding="utf-8").read().splitlines()]
    keep = [l for l in lines if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]", l)]
    if not keep:                       # 有些 GT 是纯 token 一行
        keep = [l for l in lines if l and not l.startswith(("title", "1=", "2/4", "4/4", "%"))]
    s = " ".join(keep).replace("(", " ").replace(")", " ")
    return [x for x in s.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$", x) or x == "-"]

def key(t):
    j = token_to_json(t)
    return (j["digit"], j["low"], len(j["voice"]), j["beam"], j["dotted"], j["accidental"])

def ok(toks, gt):
    sm = SequenceMatcher(None, [key(x) for x in toks], [key(x) for x in gt])
    return sum(i2-i1 for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag == "equal")

SCORES = [
    ("时间都去哪了", "train-work/gt/时间都去哪了.jpg", "train-work/gt/时间都去哪了.txt"),
    ("兄弟抱一下", "train-work/gt/兄弟抱一下.jpg", "train-work/gt/兄弟抱一下.txt"),
    ("排排坐", "train-work/gt/排排坐.jpg", "train-work/gt/排排坐.txt"),
    ("春天在哪里", "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg", "train-work/gt/春天在哪里.txt"),
]
for name, img, gtf in SCORES:
    if not os.path.exists(img) or not os.path.exists(gtf):
        print(f"{name}: 缺文件, 跳过", flush=True); continue
    gt = parse_gt(gtf)
    toks, meta = JP.transcribe(img)
    o = ok(toks, gt)
    o2 = ok(toks, gt)
    print(f"{name}: 音{len(toks)} GT{len(gt)} OK={o} ({100*o/max(len(gt),1):.0f}%)", flush=True)
