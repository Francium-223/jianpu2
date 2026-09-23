# -*- coding: utf-8 -*-
"""诊断: 打印某个音符块内的连通域, 看时值线为何没被识别。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from geo_detect import geo_detect

im = glob.glob("images-prep/hot-crawl/上春山__qinyipu-377784/*")[0]
arr = np.asarray(Image.open(im).convert("L"))
content = arr < T.TOL

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)

# 取第一个"有音符"的行带(第 461 行那批)
for s, e in bands:
    if s != 461 and not (455 <= s <= 470):
        continue
    sub = content[s:e + 1]
    if T.count_bars(sub, e - s + 1) < T.BAR_THR:
        print(f"band {s}-{e}: 被 count_bars 拒绝")
        continue
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    print(f"=== band {s}-{e}  bar_extent={be} ===")
    regs = T.crop_note_regions(sub)
    print(f"共 {len(regs)} 个候选区域")
    for (nx0, nx1, ny0, ny1) in regs[:6]:
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        gd = geo_detect(crop)
        comps = T.components(crop < T.TOL)
        print(f"\n  块 x[{nx0},{nx1}] y[{ny0},{ny1}] crop.shape={crop.shape} -> {gd}")
        # 把前 3 个块存图, 供人工核验
        if len(os.listdir("train-work") ) >= 0:
            from PIL import Image as _I
            _I.fromarray(crop).resize((crop.shape[1] * 6, crop.shape[0] * 6), _I.NEAREST).save(
                f"train-work/cropblk_{nx0}.png")
            print(f"     (已存 train-work/cropblk_{nx0}.png)")
        for c in sorted(comps, key=lambda c: -c[4]):
            print(f"     分量 x{c[0]:3d}-{c[2]:3d} y{c[1]:3d}-{c[3]:3d}  w{c[4]:3d} h{c[5]:3d}")
        # 手工复现新判据
        m = crop < 170
        digits = [c for c in comps if c[5] >= 18 and c[5] > c[4]]
        if digits:
            main = max(digits, key=lambda c: c[5])
            dx0, dy0, dx1, dy1 = main[0], main[1], main[2], main[3]
            spans = []
            for y in range(dy0, dy1 + 1):
                xr = np.where(m[y, dx0:dx1 + 1])[0]
                spans.append(int(xr.max() - xr.min() + 1) if len(xr) else 0)
            up = spans[:max(1, int(len(spans) * 0.55))]
            base = max(max(up), 1) if up else 1
            wide = [y for k, y in enumerate(range(dy0, dy1 + 1)) if spans[k] >= 1.6 * base]
            print(f"     主分量 x[{dx0},{dx1}] y[{dy0},{dy1}] spans={spans}")
            print(f"     base={base}  阈值={1.6*base:.1f}  wide行={wide}")
    break
