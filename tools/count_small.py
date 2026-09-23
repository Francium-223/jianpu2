# -*- coding: utf-8 -*-
"""统计: 被挑页宽度 < JP_MINW(700) 的谱有多少(这些会被新的"小图放大"影响)。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

def scan(dirs, label):
    tot = small = 0
    names = []
    for d in dirs:
        p = BT.pick_page(d)
        if not p:
            continue
        try:
            w, h = Image.open(p).size
        except Exception:
            continue
        tot += 1
        if w < 700:
            small += 1
            names.append((os.path.basename(d.rstrip("/\\")), w))
    print(f"{label}: {tot} 个, 宽度<700 的 {small}")
    return names

allsm = scan(sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d)), "全部源")
crawl = scan(sorted(d for d in glob.glob("images-prep/jianpucn-pop/*") if os.path.isdir(d)), "jianpucn-pop")
with open("train-work/small_sheets.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(n for n, w in crawl))
print("jianpucn-pop 的小图名单已存 train-work/small_sheets.txt")
