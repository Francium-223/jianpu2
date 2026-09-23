# -*- coding: utf-8 -*-
"""看被 CV 门拒掉的行带原本产出什么 token (判断是噪声还是真音符)。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

img = r"images-prep/qupu123-crawl/11幸福花园（双谱）__qupu123-312866/002.jpg"
toks, meta = JP.transcribe(img)
from collections import defaultdict
band = defaultdict(list)
for t, m in zip(toks, meta):
    band[m["s"]].append(t)
print("按行带分组的 token:")
for s in sorted(band):
    ts = band[s]
    d = sum(1 for t in ts if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    print(f"\n行带 y={s}  ({len(ts)} token, 数字{d}):")
    print("   " + " ".join(ts))
