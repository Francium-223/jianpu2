# -*- coding: utf-8 -*-
"""纯简谱检测器: 用"整行横线"(五线谱/六线谱的谱线) 等特征区分
纯简谱 / 五线谱 / 六线谱 / 混合谱。

判据:
  long_rows = 暗像素 > 50%页宽 的行数   (谱线行的特征)
  digit_rows= 有效音符行数(复用管线几何)
  ink       = 墨密度
先只统计分布, 再定阈值。
用法: py tools/detect_kind.py [限制数]
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

def feats(path):
    im = Image.open(path).convert("L")
    w, h = im.size
    tw = 1200 if w < 700 else (2000 if w > 2000 else w)
    if tw != w:
        im = im.resize((tw, max(1, int(round(h * tw / w)))), Image.LANCZOS)
    arr = np.asarray(im)
    content = arr < T.TOL
    H, W = content.shape
    rs = content.sum(axis=1)
    long_rows = int((rs > 0.5 * W).sum())
    # 谱线成组: 相邻长横线间距在 6~22px 之间算同一组
    ys = [y for y in range(H) if rs[y] > 0.5 * W]
    groups = 0
    prev = None
    for y in ys:
        if prev is None or y - prev > 6:
            groups += 1
        prev = y
    ink = float(content.mean())
    # 音符行数(用管线的行带几何)
    ndig = 0
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    for s, e in bands:
        sub = content[s:e + 1]
        st, hl = T.strip_hlines(sub)
        cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
        tl = [c for c in cs if c[5] >= 1.15 * c[4]]
        nl = sum(1 for x in hl if x[4] >= 8)
        if (len(cs) and len(tl) / len(cs) >= 0.85) or (len(tl) >= 6 and nl >= 1):
            ndig += len(tl)
    return dict(long_rows=long_rows, groups=groups, ink=round(ink, 3), note_blocks=ndig,
                w=W, h=H)

dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
LIM = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else len(dirs)
dirs = dirs[:LIM]
print(f"检查 {len(dirs)} 个目录")
rows = []
for i, d in enumerate(dirs):
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        f = feats(p)
    except Exception:
        continue
    f["dir"] = os.path.basename(d.rstrip("/\\"))
    rows.append(f)
    if (i + 1) % 200 == 0:
        print(f"  {i+1}/{len(dirs)}", flush=True)

import collections
print("\nlong_rows(整行横线数) 分布:")
c = collections.Counter()
for r in rows:
    c[min(r["long_rows"] // 5 * 5, 60)] += 1
for k in sorted(c):
    print(f"  {k:3d}-{k+5:<3d}: {c[k]:5d}")
print(f"\n共 {len(rows)} 个谱页")
with open("train-work/kind_feats.tsv", "w", encoding="utf-8") as g:
    g.write("dir\tlong_rows\tgroups\tink\tnote_blocks\tw\th\n")
    for r in rows:
        g.write(f"{r['dir']}\t{r['long_rows']}\t{r['groups']}\t{r['ink']}\t{r['note_blocks']}\t{r['w']}\t{r['h']}\n")
print("明细 -> train-work/kind_feats.tsv")
