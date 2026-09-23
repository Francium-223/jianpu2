# -*- coding: utf-8 -*-
"""spring 的 token 按行带分组, 查 1.15 阈值下多出的 token 来自哪个行带。"""
import os, sys
from collections import defaultdict
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

IMG = "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
toks, meta = JP.transcribe(IMG)
band = defaultdict(list)
for t, m in zip(toks, meta):
    band[m["s"]].append(t)
print(f"JP_TALLR={os.environ.get('JP_TALLR')}  共 {len(toks)} token")
for s in sorted(band):
    ts = band[s]
    d = sum(1 for t in ts if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    print(f"  行带 y={s:4d}  {len(ts):3d} token (数字{d}): {' '.join(ts[:14])}")
