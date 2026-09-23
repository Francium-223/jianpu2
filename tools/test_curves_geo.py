# -*- coding: utf-8 -*-
"""验证修正后的弧线检测(纯 CPU, 不加载模型)。判据同 jp_transcribe:
stripped 里 w>=12 且 4<=h<=14 的细连通域, 且位置在数字带的上/下方。
"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

def curves_of(img):
    im = Image.open(img).convert("L")
    if im.width > 2000:
        im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
    elif im.width < 950:
        im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
    c = np.asarray(im) < T.TOL
    out = []
    for s, e in T.fine_rows(c, T.ROW_GAP):
        sub = c[s:e + 1]
        st, hl = T.strip_hlines(sub)
        regs = T.crop_note_regions(sub)
        if len(regs) < 2:
            continue
        dtop = min(r[2] for r in regs)
        dbot = max(r[3] for r in regs)
        for comp in T.components(st):
            if comp[4] >= 12 and 4 <= comp[5] <= 14 and (comp[1] >= dbot - 6 or comp[3] <= dtop + 6):
                mem = [r for r in regs if comp[0] - 4 <= (r[0] + r[1]) / 2.0 <= comp[2] + 4]
                if 2 <= len(mem) <= 6:
                    out.append((s, comp[0], comp[2], comp[1], comp[5], len(mem)))
    return out

for p, name in [
    ("train-work/gt/兄弟抱一下.jpg", "GT手写谱"),
    ("images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg", "spring 锚点"),
]:
    if not os.path.exists(p):
        print(f"{name}: 找不到"); continue
    try:
        rows = curves_of(p)
    except Exception as ex:
        print(f"{name}: 失败 {type(ex).__name__}"); continue
    print(f"=== {name} ===  检出弧线 {len(rows)} 条")
    for s, x0, x1, y, h, k in rows[:8]:
        print(f"   y行={s:4d} x=[{x0},{x1}] w={x1-x0} h={h} 罩{k}个数字")
