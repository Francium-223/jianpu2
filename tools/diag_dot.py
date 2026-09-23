# -*- coding: utf-8 -*-
"""找 时间都去哪了 里的附点音符(数字右侧小点), 打印附点相对数字的位置特征。
用于安全地把附点纳入裁剪而不误吞相邻数字。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
F="train-work/gt/时间都去哪了.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<170
# 找含附点的音符行(有 '1. 2.' 等): 扫描各段, 找 '数字x 右侧紧邻小点' 的结构
found=0
for (s,e) in T.fine_rows(content,T.ROW_GAP):
    sub=content[s:e+1]; H=e-s+1
    if T.count_bars(sub,H)<T.BAR_THR: continue
    comps=T.components(sub)
    digits=[c for c in comps if c[5]>=14 and c[5]<=45 and c[5]>c[4] and c[4]>=6]
    dots=[c for c in comps if 2<=c[4]<=8 and 2<=c[5]<=10]
    for d in digits:
        # 找数字右侧紧邻的小点(附点): x0>d[2], 且x0-d[2]<10, y 在数字中央附近
        for p in dots:
            if p[0] > d[2] and p[0]-d[2] < 12 and p[1] >= d[1]-4 and p[3] <= d[3]+4:
                if found<8:
                    print(f"数字x[{d[0]}-{d[2]}]y[{d[1]}-{d[3]}]w{d[4]}h{d[5]}  附点x[{p[0]}-{p[2]}]y[{p[1]}-{p[3]}]w{p[4]}h{p[5]} 附点距数字右缘={p[0]-d[2]}px")
                    found+=1
                break
print("样例附点音符:",found)
