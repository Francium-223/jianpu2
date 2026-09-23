# -*- coding: utf-8 -*-
"""验证: 那些"有图但任何目录都没有转写"的谱, 是否被 transcribe_source 的静默跳过(高度>JP_MAX_H)吞了。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

MAXH = int(os.environ.get("JP_MAX_H", "5000"))
print(f"JP_MAX_H = {MAXH}（超过就静默 continue，不留记录）\n")

TARGETS = ["我是一只鱼", "需要人陪", "有点甜", "笑看风云", "时间都去哪儿了"]
for t in TARGETS:
    for g in glob.glob("images-prep/*/" + t + "*"):
        if not os.path.isdir(g):
            continue
        page = BT.pick_page(g)
        name = BT.safe_name(os.path.basename(g))
        exists = os.path.exists(f"batch-out/{name}.txt")
        if not page:
            print(f"  {t:<14} pick_page 返回 None  ({os.path.basename(g)[:40]})")
            continue
        w, h = Image.open(page).size
        flag = "**超限被静默跳过**" if h > MAXH else ("已转写" if exists else "**未转写(原因待查)**")
        print(f"  {t:<14} {w}x{h}  转写结果存在={exists}  {flag}")
        print(f"        {os.path.basename(g)[:58]}")
