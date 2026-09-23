# -*- coding: utf-8 -*-
"""验证弧线候选的垂直位置: 到底贴着音符(真弧线), 还是落在歌词区(误检)。
纯 CPU, 不受正在跑的转写影响。
"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

for name in ["Beautiful 歌曲类 简谱__jianpucn-64783"]:
    g = glob.glob("images-prep/*/" + glob.escape(name))
    if not g:
        print("找不到", name); continue
    p = BT.pick_page(g[0])
    im = Image.open(p).convert("L")
    if im.width < 950:
        im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
    c = np.asarray(im) < T.TOL
    print(f"{name[:40]}  图 {im.size}")
    shown = 0
    for s, e in T.fine_rows(c, T.ROW_GAP):
        sub = c[s:e + 1]
        st, hl = T.strip_hlines(sub)
        regs = T.crop_note_regions(sub)
        if len(regs) < 2:
            continue
        dtop = min(r[2] for r in regs)
        dbot = max(r[3] for r in regs)
        for comp in T.components(st):
            if comp[4] >= 12 and 4 <= comp[5] <= 14 and (comp[1] >= dbot - 6 or comp[3] <= dtop + 6):
                mem = [r for r in regs if comp[0] - 4 <= (r[0] + r[1]) / 2.0 <= comp[2] + 4]
                if 2 <= len(mem) <= 6:
                    where = "上方" if comp[3] <= dtop + 6 else "下方"
                    print(f"   行y={s:4d} 数字带[{dtop},{dbot}]  候选 y=[{comp[1]},{comp[3]}] "
                          f"w={comp[4]} h={comp[5]} {where} 罩{len(mem)}块")
                    shown += 1
        if shown and s > 400:
            break
    print(f"   共列出 {shown} 条")
