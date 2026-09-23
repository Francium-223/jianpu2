# -*- coding: utf-8 -*-
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
import pipeline as P
from geo_detect import _components, geo_detect
toks,meta=P.transcribe("train-work/gt/时间都去哪了.jpg")
# 找 s6 块位置
for i,b in enumerate(meta):
    if b.get("tok")=="s6":
        print(f"s6 块: band{b['band']} x[{b['x0']}-{b['x1']}] ny0{b['ny0']} y1{b['y1']}")
        # 取原图该区域, 放大看低八点
        nx0,nx1,ny0,ny1=b['x0'],b['x1'],b['ny0'],b['y1']; s=b['s']; e=b['e']
        sub=Q.bound_to_note_row(np.asarray(Image.open("train-work/gt/时间都去哪了.jpg").convert("L"))[s:e+1],nx0,nx1,ny0,ny1,None)
        if sub is None or sub.size==0: continue
        m=sub<170; comps2=_components(m); main=max(comps2,key=lambda c:c[5],default=None)
        if main:
            print(f"  主数字 y[{main[1]}-{main[3]}] 行剖面={m.sum(axis=1).tolist()}")
            for c in comps2:
                if c is main: continue
                x0,y0,x1,y1,w,h=c[:6]
                rel="下方" if y0>main[3]-1 else ("上方" if y1<main[1]+1 else "侧")
                print(f"    副 x[{x0}-{x1}] y[{y0}-{y1}] w{w} h{h} {rel}")
