# -*- coding: utf-8 -*-
"""对比测试: 附点修复 + CV 行带门 的效果。用法: py -3.13 tools/test_dot_cv.py"""
import os, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT
import jp_transcribe as JP

SHEETS = [
    ("友谊天长地久", r"images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003.jpg"),
    ("幸福花园002", r"images-prep/qupu123-crawl/11幸福花园（双谱）__qupu123-312866/002.jpg"),
    ("歌唱春天002", r"images-prep/qupu123-crawl/12歌唱春天（双谱）__qupu123-316431/002.jpg"),
]
# 友谊天长地久 3394px -> 走切页
BT.split_pages(SHEETS[0][1])

for name, img in SHEETS:
    t0 = time.time()
    try:
        toks, meta = BT.transcribe_paged(img, "train-work/_t.txt", "train-work/_t.png")
    except Exception as ex:
        print(f"{name}: 失败 {type(ex).__name__} {ex}")
        continue
    d = x = r = dot = 0
    for t in toks:
        core = t.lstrip("qsdh,").rstrip("'.")
        if core and core[-1] in "1234567":
            d += 1
        elif core == "0":
            r += 1
        if "x" in t:
            x += 1
        if "." in t:
            dot += 1
    print(f"{name:12s} 音{len(toks):4d} 数字{d:4d} 休止{r:3d} 附点{dot:3d} x{x:3d} ({time.time()-t0:.0f}s)")
