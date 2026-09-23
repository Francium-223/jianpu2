# -*- coding: utf-8 -*-
"""查 processor 对小 crop 的处理: 实际 patch 数。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import transcribe_qwen as Q
import jp_transcribe as JP

IMG = "images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg"
arr = np.asarray(Image.open(IMG).convert("L"))
content = arr < T.TOL
JP._init()
proc = JP._proc
print("processor 配置:")
for k in ("min_pixels", "max_pixels", "size", "patch_size", "merge_size"):
    print("  ", k, "=", getattr(proc.image_processor, k, getattr(proc, k, None)))

crops = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP)[:2]:
    sub = content[s0:e0 + 1]
    rg = arr[s0:e0 + 1]
    be = Q.bar_extent(sub)
    for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub)[:4]:
        c = Q.bound_to_note_row(rg, nx0, nx1, ny0, ny1, be)
        if c is not None and c.size:
            crops.append(c)
print(f"\n样例 crop 尺寸: {[c.shape for c in crops[:4]]}")
imgs = [Image.fromarray(c).convert("RGB") for c in crops[:4]]
enc = proc(images=imgs, text=["x"] * len(imgs), padding=True, return_tensors="pt")
print("image_grid_thw:", enc["image_grid_thw"].tolist())
tot = int(np.prod(enc["image_grid_thw"][0].tolist()))
print(f"每个 crop 的 patch 数 ≈ {tot}")
