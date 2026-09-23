# -*- coding: utf-8 -*-
"""放松条件扫描: 数字上方到底有没有细弧线? 逐行列出"在数字顶上方"的所有细连通域。"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

IMG = "train-work/gt/兄弟抱一下.jpg"
im = Image.open(IMG).convert("L")
if im.width > 2000:
    im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
c = np.asarray(im) < T.TOL
print(f"图 {im.size}")
for bi, (s, e) in enumerate(T.fine_rows(c, T.ROW_GAP)):
    sub = c[s:e + 1]
    st, hl = T.strip_hlines(sub)
    regs = T.crop_note_regions(sub)
    if len(regs) < 3:
        continue
    dtop = min(r[2] for r in regs)
    # 放松: 所有细连通域, 不看位置
    thin = [x for x in T.components(st) if x[5] <= 12]
    above = [x for x in hl if x[3] <= dtop - 2]
    print(f"\n行{bi} y={s}-{e} 块{len(regs)} 数字顶(块内y)={dtop}")
    print(f"   strip_hlines 剥掉 {len(hl)} 条, 其中在数字上方 {len(above)} 条")
    for h in sorted(above, key=lambda z: -z[4])[:5]:
        print(f"      x=[{h[0]},{h[2]}] y=[{h[1]},{h[3]}] w={h[4]} h={h[5]}")
    # 没被剥掉的细连通域(可能是弧线没被识别为横线)
    for x in sorted(thin, key=lambda z: -z[4])[:4]:
        pos = "上方" if x[3] <= dtop - 2 else ("下方" if x[1] >= dtop + 30 else "重叠")
        print(f"      细块 x=[{x[0]},{x[2]}] y=[{x[1]},{x[3]}] w={x[4]} h={x[5]} {pos}")
    if bi >= 4:
        break
