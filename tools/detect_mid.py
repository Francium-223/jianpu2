# -*- coding: utf-8 -*-
"""检测宽度在 [700,950) 的谱 —— 新的 JP_MINW=950 会把它们放大到 1200, 故需重转。
输出 train-work/mid_need.txt
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
need = []
tot = 0
for d in sorted(x for x in glob.glob("images-prep/*/*") if os.path.isdir(x)):
    nm = BT.safe_name(os.path.basename(d.rstrip("/\\")))
    if nm not in have:
        continue
    tot += 1
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        w, h = Image.open(p).size
    except Exception:
        continue
    if 700 <= w < 950:
        need.append(os.path.basename(d.rstrip("/\\")))
print(f"当前语料 {tot} 个; 宽度在 [700,950) 的 {len(need)}")
with open("train-work/mid_need.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(need))
