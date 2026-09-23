# -*- coding: utf-8 -*-
"""诊断高度门: 逐行带打印 组件高度分布 / _hmax / 候选数字块高度。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

for img in sys.argv[1:]:
    arr = np.asarray(Image.open(img).convert("L"))
    content = arr < T.TOL
    print(f"\n######## {os.path.basename(img)} ########")
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    for s, e in bands:
        sub = content[s:e + 1]
        stripped, hlines = T.strip_hlines(sub)
        cs = [c for c in T.components(stripped) if 10 <= c[5] <= 45 and c[4] >= 3]
        if not cs:
            continue
        hs = sorted(c[5] for c in cs)
        hmax = hs[-1]
        med = hs[len(hs) // 2]
        # 数字块(经 crop_note_regions 的判据)高度
        regs = T.crop_note_regions(sub)
        rh = []
        for (nx0, nx1, ny0, ny1) in regs:
            if ny1 - ny0 + 1 >= 12:
                rh.append(ny1 - ny0 + 1)
        rh = sorted(rh)
        rmed = rh[len(rh) // 2] if rh else 0
        print(f"  y={s:4d}-{e:4d} h={e-s+1:3d} n={len(cs):3d} hmax={hmax:3d} med={med:3d} "
              f"数字块{len(rh):3d} 块med={rmed:3d}  heights={hs}")
