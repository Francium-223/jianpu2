# -*- coding: utf-8 -*-
"""纯简谱检测(快版): 只算"整行横线数" long_rows = 暗像素占比 >50% 页宽的行数。

原理: 五线谱/六线谱的每组 5-6 条谱线横跨整页 -> 一页会积累几十条整行横线;
纯简谱页几乎没有这种行(时值线只跨几个数字)。实测:
  纯简谱  K歌之王(lr=0) / 烟火里的尘埃(lr=0)
  吉他谱  烟火里的尘埃_gita(lr=66) / 任我行(lr=103)
用法: py tools/kind_fast.py [限制数]
输出: train-work/kind_fast.tsv  (dir, long_rows, w, h, ink)
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

LIM = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
if LIM:
    dirs = dirs[:LIM]
print(f"检查 {len(dirs)} 个目录", flush=True)

out = open("train-work/kind_fast.tsv", "w", encoding="utf-8", newline="")
w = csv.writer(out, delimiter="\t")
w.writerow(["dir", "long_rows", "w", "h", "ink"])
n = 0
for i, d in enumerate(dirs):
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        im = Image.open(p).convert("L")
        iw, ih = im.size
        tw = 1200 if iw < 700 else (2000 if iw > 2000 else iw)
        if tw != iw:
            im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
        a = np.asarray(im)
        c = a < T.TOL
        W = c.shape[1]
        rs = c.sum(axis=1)
        lr = int((rs > 0.5 * W).sum())
        w.writerow([os.path.basename(d.rstrip("/\\")), lr, c.shape[1], c.shape[0], round(float(c.mean()), 4)])
        n += 1
    except Exception:
        pass
    if (i + 1) % 500 == 0:
        print(f"  {i+1}/{len(dirs)}", flush=True)
out.close()
print(f"完成 {n} 个 -> train-work/kind_fast.tsv")
