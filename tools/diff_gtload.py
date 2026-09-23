# -*- coding: utf-8 -*-
"""直接 diff 新旧 GT 加载逻辑, 找出 兄弟抱一下 的 3 个点差在哪。"""
import io, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import load_gt
from token_json import is_tuplet_marker, is_marker

f = "train-work/gt/兄弟抱一下.txt"
t = io.open(f, encoding="utf-8", errors="replace").read()
lines = [l for l in t.splitlines() if re.search(r"[0-9x\-]", l)
         and not re.match(r"^\s*(title|MBID|type|copyright|OctavesAfter|1=|2/4|4/4|%|$)", l)]

# 旧逻辑
s = " ".join(lines)
for ch in "(){}[]|~:":
    s = s.replace(ch, " ")
s = re.sub(r"[^0-9qsdh',\.x\- ]", " ", s)
OLD = [x for x in s.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$", x) or x == "-"]

NEW = load_gt(f)
print(f"旧 {len(OLD)} 个 / 新 {len(NEW)} 个")

# 用 difflib 找差异
from difflib import SequenceMatcher
sm = SequenceMatcher(None, OLD, NEW, autojunk=False)
for tag, i1, i2, j1, j2 in sm.get_opcodes():
    if tag != "equal":
        print(f"  [{tag}] 旧[{i1}:{i2}]={OLD[i1:i2]}  新[{j1}:{j2}]={NEW[j1:j2]}")
