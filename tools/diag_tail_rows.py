# -*- coding: utf-8 -*-
"""检查 spring 全图的 fine_rows 波段 + count_bars, 找 '眼睛里...' 尾声行是否被跳过。
打印每个波段 y范围/bar数/是否PASS。"""
import os,sys; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
F="images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr=np.asarray(Image.open(F).convert("L")); content=arr<T.TOL
segs=T.fine_rows(content,T.ROW_GAP)
print(f"fine_rows 共 {len(segs)} 段")
for i,(s,e) in enumerate(segs):
    sub=content[s:e+1]; H=e-s+1
    bars=T.count_bars(sub,H)
    if not (760<=s<=1000): continue  # 只看尾部
    print(f"  段{i} y[{s},{e}] H={H} bars={bars} {'PASS' if bars>=T.BAR_THR else 'SKIP'}")
