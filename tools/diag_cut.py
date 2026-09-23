# -*- coding: utf-8 -*-
"""打印问候歌每个块的 y 坐标与裁剪结果, 确认数字是否被切。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
print(f"行带 {len(bands)} 个")

shown = 0
for s, e in bands:
    sub = content[s:e + 1]
    if T.count_bars(sub, e - s + 1) < T.BAR_THR:
        continue
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    btop, bbot = be if be else (-1, -1)
    print(f"\n=== 行带 y[{s},{e}] h={e-s+1}  bar_extent=({btop},{bbot}) ===")
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        y1_old = min(max(ny1, bbot), bbot + 6)
        y1_new = ny1 if y1_old < ny1 else y1_old
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        ch = 0 if crop is None else crop.shape[0]
        flag = "  <-- 截断! 数字被切" if y1_old < ny1 else ""
        print(f"  块 x[{nx0:3d},{nx1:3d}] 块y[{ny0:3d},{ny1:3d}] h={ny1-ny0+1:3d}"
              f"  裁剪y1: {y1_old}->{y1_new}  crop高={ch}{flag}")
        shown += 1
    if shown > 24:
        break
