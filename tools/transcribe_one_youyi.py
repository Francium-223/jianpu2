# -*- coding: utf-8 -*-
"""转写单张谱: 友谊天长地久(日语版)。"""
import os, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

img = r"images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003.jpg"
t0 = time.time()
toks, meta = BT.transcribe_paged(img, "train-work/友谊天长地久.txt", "train-work/友谊天长地久.png")
s = " ".join(toks)
open("train-work/友谊天长地久.txt", "w", encoding="utf-8").write(s)
d = x = r = 0
for t in toks:
    core = t.lstrip("qsdh,").rstrip("'.")
    if not core:
        continue
    if core[-1] in "1234567":
        d += 1
    elif core == "0":
        r += 1
    if "x" in t:
        x += 1
print(f"友谊天长地久(日语版): 音{len(toks)} 数字{d} 休止{r} x{x}  ({time.time()-t0:.0f}s)")
print(s)
