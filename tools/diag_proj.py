# -*- coding: utf-8 -*-
"""诊断: 将进酒的行投影为何没有空白 -> fine_rows 无法分行。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

src = sorted(glob.glob("images-prep/qupu123-crawl/将进酒__qupu123-382162/*.jpg"),
             key=os.path.getsize)[-1]
arr = np.asarray(Image.open(src).convert("L"))
content = arr < T.TOL
H, W = content.shape
print(f"图 {W}x{H}")

stripped = T.strip_tall_verticals(content, 60)
proj_raw = content.sum(axis=1)
proj_st = stripped.sum(axis=1)

print(f"\n原始 proj:  min={proj_raw.min()}  max={proj_raw.max()}  <=2 的行数={int((proj_raw<=2).sum())}")
print(f"抹线后 proj: min={proj_st.min()}  max={proj_st.max()}  <=2 的行数={int((proj_st<=2).sum())}")

print("\n抹线前后, 每 40 行的投影(找行间空白):")
print(f"{'y':>5} {'raw':>7} {'strip':>7}")
for y in range(0, H, 40):
    seg_r = proj_raw[y:y+40].min(); seg_s = proj_st[y:y+40].min()
    bar_r = "#" * min(60, int(seg_r / 20)); bar_s = "#" * min(60, int(seg_s / 20))
    print(f"{y:5d} {seg_r:7d} {seg_s:7d}  {bar_s}")

# 抹线后仍然"每行都有像素"的话, 看是哪些列在行间有内容
gaps = [y for y in range(1, H-1) if proj_st[y] <= 2]
print(f"\n抹线后仍 <=2 的行: {len(gaps)}")

# 检查: 抹掉的长竖线有多少列
diff = (content.astype(np.int8) - stripped.astype(np.int8))
cols = np.where(diff.sum(axis=0) > 0)[0]
print(f"被抹掉的列: {len(cols)} 列   x 范围 [{cols.min() if len(cols) else -1},{cols.max() if len(cols) else -1}]")
