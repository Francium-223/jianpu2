# -*- coding: utf-8 -*-
"""关键谱快速验证: 转写并统计 数字/?/x。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

def stat(name, img):
    toks, meta = JP.render(img, "train-work/t_" + name + ".png")
    q = x = d = 0
    for t in toks:
        core = t.lstrip("qsdh,").rstrip("'.")
        if core == "?": q += 1
        elif core == "x": x += 1
        elif core and core[-1] in "1234567": d += 1
    print(f"{name:14s} 音{len(toks):4d} 数字{d:4d} ?{q:3d} x{x:3d}")
    return toks

tests = [
    ("blueberry", r"images-prep/qupu123-crawl/Blue_Berry_Hill_鸟饭树山（蓝莓山）__qupu123-375493/002.jpg"),
    ("幸福花园002", r"images-prep/qupu123-crawl/11幸福花园（双谱）__qupu123-312866/002.jpg"),
    ("歌唱春天002", r"images-prep/qupu123-crawl/12歌唱春天（双谱）__qupu123-316431/002.jpg"),
    ("奋发向上003", r"images-prep/qupu123-crawl/奋发向上__qupu123-327224/003.jpg"),
]
for name, img in tests:
    try:
        stat(name, img)
    except Exception as ex:
        print(f"{name}: 失败 {type(ex).__name__} {ex}")
