# -*- coding: utf-8 -*-
"""按 ID 找目录, 裁出指定 y 区间看图。用法: py tools/crop_by_id.py <id> <y0> <y1> <out>"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

kid, y0, y1, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
hits = [p for p in glob.glob("images-prep/*/*") if kid in os.path.basename(p)]
if not hits:
    print("找不到", kid); sys.exit()
page = BT.pick_page(hits[0])
im = Image.open(page)
print(f"{os.path.basename(hits[0])}  {page}  {im.size}")
c = im.crop((0, y0, im.width, min(y1, im.height)))
if c.width > 1400:
    c = c.resize((1400, int(c.height * 1400 / c.width)), Image.LANCZOS)
c.save(out)
print("saved", out, c.size)
