# -*- coding: utf-8 -*-
"""检测当前语料(batch-out)里"被挑页宽 < 700px"的谱 —— 它们没享受小图放大修复。
输出 train-work/small_need.txt (目录名)
"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
need = []
for d in dirs:
    nm = BT.safe_name(os.path.basename(d.rstrip("/\\")))
    if nm not in have:
        continue
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        w, h = Image.open(p).size
    except Exception:
        continue
    if w < 700:
        need.append(os.path.basename(d.rstrip("/\\")))
print(f"当前语料 {len(have)} 个; 其中被挑页宽<700 的 {len(need)}")
with open("train-work/small_need.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(need))
