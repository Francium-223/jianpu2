# -*- coding: utf-8 -*-
"""段11(尾声 y865-996): 看 细高连通域 分布, 为什么 count_bars 返回 0.
打印 小节线候选 高度 vs count_bars 的判定。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
s,e=T.fine_rows(content,T.ROW_GAP)[11]; sub=content[s:e+1]; H=e-s+1
comps=T.components(sub)
thin=[c for c in comps if c[4]<=5 and c[5]>=10]
print(f"段11 y[{s},{e}] H={H} 细高候选 {len(thin)} 个")
if thin:
    hmax=max(c[5] for c in thin)
    print(f"最高细高 {hmax}, 0.8*hmax={0.8*hmax}")
    real=[c for c in thin if c[5]>=0.8*hmax and c[5]>=20]
    print(f"满足(>=0.8max & >=20)的节线候选 {len(real)} 个:")
    for c in real:
        print(f"  x[{c[0]}-{c[2]}] y[{c[1]}-{c[3]}] h={c[5]}")
    print(f"count_bars 返回 {T.count_bars(sub,H)}")
    # 打印薄的但高度在 20-40 的(潜在节线被 H=132 撑破?)
    print("\n所有细高(竖)连通域:")
    for c in sorted(thin,key=lambda c:c[0]):
        print(f"  x[{c[0]}-{c[2]}] y[{c[1]}-{c[3]}] w={c[4]} h={c[5]}")
