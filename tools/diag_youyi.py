# -*- coding: utf-8 -*-
"""诊断 友谊天长地久: 逐行带 + 逐块 dump(位置/类型/token/geo_detect), 查
(1) 标题行内容为何变成 token  (2) 附点为何全丢。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
from classify_block import classify_block
from geo_detect import geo_detect, _components
import batch_transcribe as BT
import jp_transcribe as JP

img = r"images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003.jpg"
pages = BT.split_pages(img)
print(f"切页: {len(pages)} 页 -> {[os.path.basename(p) for p in pages]}")

page = pages[0]
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL
print(f"第一页 {arr.shape[1]}x{arr.shape[0]}")

bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
print(f"行带 {len(bands)} 个\n")

print("=== 行带: y范围 / frac / 下划线 / 是否接受 ===")
for s, e in bands:
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
    tall = [c for c in cs if c[5] >= 1.4 * c[4]]
    frac = (len(tall) / len(cs)) if cs else 0.0
    nline = sum(1 for h in hlines if h[4] >= 8)
    acc = frac >= 0.85 or (len(tall) >= 6 and nline >= 1)
    print(f"  y={s:4d}-{e:4d} h={e-s+1:3d} n={len(cs):3d} tall={len(tall):3d} "
          f"frac={frac:.2f} 下划线={nline:3d} {'接受' if acc else '丢弃'}")

print("\n=== 逐块 dump (接受的行带) ===")
for s, e in bands:
    sub = content[s:e + 1]
    stripped, hlines = T.strip_hlines(sub)
    cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
    tall = [c for c in cs if c[5] >= 1.4 * c[4]]
    frac = (len(tall) / len(cs)) if cs else 0.0
    if not (frac >= 0.85 or (len(tall) >= 6 and sum(1 for h in hlines if h[4] >= 8) >= 1)):
        continue
    row_gray = arr[s:e + 1]
    be = Q.bar_extent(sub)
    print(f"\n--- 行带 y={s}-{e} (h={e-s+1}) ---")
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
        crop = Q.bound_to_note_row(row_gray, nx0, nx1, ny0, ny1, be)
        if crop is None or crop.size == 0:
            continue
        bt = classify_block(crop)
        gd = geo_detect(crop)
        m = crop < 170
        comps = _components(m)
        # 块内所有连通域的 (x,y,w,h)
        cc = [(c[0], c[1], c[4], c[5]) for c in comps]
        print(f"  x=[{nx0},{nx1}] y=[{ny0},{ny1}] crop={crop.shape[1]}x{crop.shape[0]} "
              f"bt={bt:6s} geo={gd} 块内域={cc}")
