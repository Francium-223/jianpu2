# -*- coding: utf-8 -*-
"""列出"只有 png/jpeg、没有 jpg"的谱目录 -> train-work/png_only.txt。

为什么需要: pick_page 以前只认 *.jpg, qupu123 少数曲子只发 .png(实测《领悟》),
这些谱被**静默跳过**、永远转不了。修了 pick_page 之后, 用这份名单把它们补转。
用法: py -3.13 tools/png_only_dirs.py
"""
import glob
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
import batch_transcribe as BT

RESULT_DIRS = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]
done = set()
for rd in RESULT_DIRS:
    for f in glob.glob(f"{rd}/*.txt"):
        done.add(os.path.basename(f)[:-4])

todo = []
for d in sorted(glob.glob("images-prep/*/*")):
    if not os.path.isdir(d):
        continue
    imgs = [f for f in glob.glob(os.path.join(d, "*"))
            if os.path.splitext(f)[1].lower() in (".jpg", ".jpeg", ".png", ".webp")]
    img = [f for f in imgs if os.path.splitext(f)[1].lower() in (".jpg", ".jpeg")]
    if imgs and not img:                      # 一张 jpg 都没有
        name = os.path.basename(d)
        if BT.safe_name(name) in done:        # 已经有结果的不必重排
            continue
        if BT.pick_page(d):
            todo.append(name)

with open("train-work/png_only.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(todo) + ("\n" if todo else ""))
print(f"只有 png/jpeg 且没转过的谱目录: {len(todo)} 个 -> train-work/png_only.txt")
for t in todo[:12]:
    print("   " + t[:60])
