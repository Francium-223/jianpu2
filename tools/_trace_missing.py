# -*- coding: utf-8 -*-
"""查"真缺"名单里那几首到底躺在哪 —— 是没转、被判非纯、还是择优落选。"""
import glob
import os
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DIRS = ["jianpu-db-out/scores", "batch-out", "batch-out-dup", "batch-out-bad",
        "batch-out-empty", "batch-out-suspect"]
for t in ("我是一只鱼", "姐妹", "需要人陪", "有点甜", "今宵多珍重", "笑看风云",
          "时间都去哪儿了", "双截棍", "雨蝶", "当"):
    row = []
    for d in DIRS:
        n = [os.path.basename(f)[:-4] for f in glob.glob(d + "/*.txt")
             if t in os.path.basename(f)]
        if n:
            row.append(f"{os.path.basename(d)}={len(n)}")
    imgs = len([g for g in glob.glob("images-prep/*/" + t + "*") if os.path.isdir(g)])
    print(f"  {t:<14} 谱目录: {' '.join(row) if row else '(各目录全无)'}   图片目录 {imgs}")
