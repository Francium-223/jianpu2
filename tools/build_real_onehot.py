# -*- coding: utf-8 -*-
"""finetune_gt.jsonl(真实音符图+GT token) → 6维 one-hot 标注, 供 CNN 微调。
用法: py -3.13 tools/build_real_onehot.py
输出 train-data-atoms-v4-json/real_onehot.jsonl
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from token_json import token_to_json
sys.stdout.reconfigure(encoding="utf-8")
import re

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = "train-work/finetune_gt.jsonl"
OUT = "train-data-atoms-v4-json/real_onehot.jsonl"

DIGITS = ["1", "2", "3", "4", "5", "6", "7", "0", "x"]
BEAMS = [0, 1, 2, 3, 4]
LOWS = [0, 1, 2, 3]
VOICES = [0, 1, 2, 3]
DOTS = [0, 1]
ACCS = ["", "#", "b"]


def onehot(v, cats):
    if v not in cats:
        return [0] * len(cats)
    i = cats.index(v)
    return [0] * i + [1] + [0] * (len(cats) - i - 1)


out = []
skip = 0
for ln in open(SRC, encoding="utf-8"):
    r = json.loads(ln)
    tok = r["text"]
    if tok in ("-",) or not re.match(r"^[,']*[qsdh]*[,']*[1-7x][.,'qsdhc\-]*$", tok):
        skip += 1; continue
    js = token_to_json(tok)
    d = js["digit"]
    # 真实 GT 可能含 8/9(快捷键) 罕见, 跳过
    if d not in DIGITS:
        skip += 1; continue
    label = {
        "digit": onehot(d, DIGITS),
        "beam": onehot(js["beam"], BEAMS),
        "low": onehot(js["low"], LOWS),
        "voice": onehot(len(js["voice"]), VOICES),
        "dotted": onehot(js["dotted"], DOTS),
        "accidental": onehot(js["accidental"], ACCS),
    }
    out.append({"image": r["image"], "label": label})

with open(OUT, "w", encoding="utf-8") as f:
    for r in out:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
print(f"真实音符微调数据 {len(out)} 条, 跳过 {skip} -> {OUT}")
