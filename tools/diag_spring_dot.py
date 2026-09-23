# -*- coding: utf-8 -*-
"""查 spring 里 3 个"5."(假附点) 的来源: dump 该块的连通域。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import jp_transcribe as JP
from geo_detect import _components, geo_detect

IMG = "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr = np.asarray(Image.open(IMG).convert("L"))
content = arr < T.TOL
toks, meta = JP.transcribe(IMG)
for t, m in zip(toks, meta):
    if "." in t:
        s, nx0, nx1, ny0, ny1 = m["s"], m["x0"], m["x1"], m["ny0"], m["y1"]
        row_gray = arr[s:s + 200]
        crop = row_gray[:, :]
        # 直接用 meta 画出的框在整图上的位置取块
        sub = content[s: s + 200]
        # 重建该块的 crop: 与 jp_transcribe 相同(用图的灰度 + 行带偏移)
        y0 = s + max(0, ny0 - T.PAD)
        y1 = s + ny1 + T.PAD
        c = arr[y0:y1, max(0, nx0 - 2):nx1 + 2]
        print(f"\ntoken {t!r} 图坐标 y=[{y0},{y1}] x=[{max(0,nx0-2)},{nx1+2}] crop={c.shape[1]}x{c.shape[0]}")
        m2 = c < 170
        comps = _components(m2)
        for cc in sorted(comps, key=lambda z: z[0]):
            print(f"   域 x=[{cc[0]},{cc[2]}] y=[{cc[1]},{cc[3]}] w={cc[4]} h={cc[5]}")
        print("   geo:", geo_detect(c))
