# -*- coding: utf-8 -*-
"""统计 qupu123 目录里各页的"简谱程度"(几何评分), 用来判定 pick_page 是否挑错页。
简谱页特征: 有大量瘦高数字块 + 时值下划线 + 延音杠; 五线谱页特征: 大量细横线(五线)。
纯几何, 不加载模型。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

def page_score(path):
    """返回 (digit块数, 五线谱横线数)。简谱页 digit 高、hline 少; 五线谱页反过来。"""
    arr = np.asarray(Image.open(path).convert("L"))
    content = arr < T.TOL
    ndig = 0
    nstaff = 0
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        for s, e in T.split_row_inner(content, s0, e0):
            sub = content[s:e + 1]
            stripped, hlines = T.strip_hlines(sub)
            # 五线谱: 细横线横跨很宽(接近整行宽) -> 记一次
            W = sub.shape[1]
            nstaff += sum(1 for l in hlines if l[4] >= 0.6 * W)
            cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
            ndig += sum(1 for c in cs if c[5] >= 1.4 * c[4])
    return ndig, nstaff

dirs = sys.argv[1:] or sorted(glob.glob("images-prep/qupu123-crawl/*/"))
print(f"目录 {len(dirs)} 个\n")
multi = 0
wrong_pick = 0
same = 0
for d in dirs[:40]:
    fs = sorted(glob.glob(os.path.join(d, "*.jpg")))
    fs = [f for f in fs if "__pg" not in f]
    if len(fs) < 2:
        continue
    multi += 1
    scores = []
    for f in fs:
        try:
            nd, ns = page_score(f)
        except Exception:
            nd, ns = -1, -1
        scores.append((os.path.basename(f), nd, ns, os.path.getsize(f)))
    pick = max(scores, key=lambda x: x[3])[0]
    best = max(scores, key=lambda x: x[1])[0]
    tag = "一致" if pick == best else "**挑错**"
    if pick == best: same += 1
    else: wrong_pick += 1
    print(f"{os.path.basename(d)[:38]:40s} {tag}")
    for n, nd, ns, sz in scores:
        mark = ""
        if n == pick: mark += " <-最大文件"
        if n == best: mark += " <-最高简谱分"
        print(f"    {n:12s} 简谱块{nd:5d} 五线{ns:4d} {sz//1024:5d}KB{mark}")
print(f"\n多页目录 {multi}: pick_page 与最高简谱分一致 {same}, 挑错 {wrong_pick}")
