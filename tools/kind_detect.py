# -*- coding: utf-8 -*-
"""纯简谱检测(定稿): 灰度<128 且横向覆盖 >60%页宽 的行数 = nline_big。
纯简谱几乎为 0(实测 K歌之王 0, 十年 11); 五线谱/六线谱/总谱/吉他混合谱普遍 >=25
(实测 第一次 25 / 任我行 29 / 夜空五线谱 47 / 最佳损友 51 / 爱情转移 126 / 童话总谱 175)。
判据: nline_big >= JP_BADLINE(默认20) -> 非纯简谱, 不该转写。
用法: py tools/kind_detect.py [限制数]   输出 train-work/kind_final.tsv
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

BADLINE = int(os.environ.get("JP_BADLINE", "20"))

def nline_big(path):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 700 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im)
    W = g.shape[1]
    c = g < 128
    rs = c.sum(axis=1)
    return int((rs > 0.60 * W).sum()), W, g.shape[0]

if __name__ == "__main__":
    LIM = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
    dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
    if LIM:
        dirs = dirs[:LIM]
    print(f"检查 {len(dirs)} 个目录 (阈值 nline_big>={BADLINE})", flush=True)
    out = open("train-work/kind_final.tsv", "w", encoding="utf-8", newline="")
    w = csv.writer(out, delimiter="\t")
    w.writerow(["dir", "nline_big", "pure", "w", "h"])
    n = bad = 0
    for i, d in enumerate(dirs):
        p = BT.pick_page(d)
        if not p:
            continue
        try:
            nb, ww, hh = nline_big(p)
        except Exception:
            continue
        pure = nb < BADLINE
        if not pure:
            bad += 1
        w.writerow([os.path.basename(d.rstrip("/\\")), nb, int(pure), ww, hh])
        n += 1
        if (i + 1) % 500 == 0:
            print(f"  {i+1}/{len(dirs)}  非纯累计 {bad}", flush=True)
    out.close()
    print(f"完成 {n} 个: 纯简谱 {n-bad}, 非纯 {bad} -> train-work/kind_final.tsv")
