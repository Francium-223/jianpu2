# -*- coding: utf-8 -*-
"""量 jianpujia / qupu123 新爬批次的质量, 与 jianpucn 对比。"""
import glob
import os
import statistics
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
from PIL import Image


def stat(pat, label):
    ws, n = [], 0
    for d in glob.glob(pat):
        if not os.path.isdir(d):
            continue
        best = 0
        for f in glob.glob(d + "/*"):
            if os.path.splitext(f)[1].lower() not in (".jpg", ".jpeg", ".png", ".gif"):
                continue
            try:
                im = Image.open(f)
                best = max(best, im.width * im.height)
            except Exception:
                pass
        if best:
            ws.append(best)
            n += 1
    if not ws:
        print(f"{label:26s}   (无数据)")
        return
    big = sum(1 for w in ws if w >= 1500 * 2000) / len(ws)
    print(f"{label:26s} {n:5d} 首   中位像素 {statistics.median(ws):>10,.0f}   "
          f">=300万像素 {100*big:>3.0f}%")


print(f"{'源/批次':26s} {'谱数':>5s}   {'中位像素':>10s}   {'高清占比':>8s}")
print("-" * 66)
for pat, label in [
    ("images-prep/qupu123-*/*", "qupu123 (高清新爬)"),
    ("images-prep/jianpujia-*/*", "jianpujia (排版图)"),
    ("images-prep/jianpucn-*/*", "jianpucn (旧主力, 扫描)"),
    ("images-prep/qupu123-crawl/*", "qupu123 (历史批次)"),
    ("images-prep/jianpujia-crawl/*", "jianpujia (历史批次)"),
]:
    stat(pat, label)

print()
tot = 0
for d in sorted(glob.glob("images-prep/qupu123-*")):
    if os.path.isdir(d):
        n = len([x for x in glob.glob(d + "/*") if os.path.isdir(x)])
        tot += n
print(f"qupu123 新爬合计: {tot} 首")
tot2 = 0
for d in sorted(glob.glob("images-prep/jianpujia-*")):
    if os.path.isdir(d):
        tot2 += len([x for x in glob.glob(d + "/*") if os.path.isdir(x)])
print(f"jianpujia 合计:   {tot2} 首")
