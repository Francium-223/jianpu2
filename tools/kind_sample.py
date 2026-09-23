# -*- coding: utf-8 -*-
"""按 long_rows/组数 档位抽样导出页面图, 供肉眼验证。用法: py tools/kind_sample.py"""
import csv, glob, os, random, shutil, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT
from PIL import Image

rows = list(csv.DictReader(open("train-work/kind_v2.tsv", encoding="utf-8"), delimiter="\t"))
for r in rows:
    r["staff_groups"] = int(r["staff_groups"])
    r["w"] = int(r["w"])
    r["h"] = int(r["h"])

def export(d, tag):
    g = glob.glob("images-prep/*/" + glob.escape(d))
    if not g:
        return None
    p = BT.pick_page(g[0])
    if not p:
        return None
    im = Image.open(p).convert("RGB")
    if im.width > 1000:
        im = im.resize((1000, int(im.height * 1000 / im.width)), Image.LANCZOS)
    out = f"train-work/kind_{tag}.png"
    im.save(out)
    return out

random.seed(7)
for lo, hi, tag in [(3, 8, "mid"), (8, 99, "bad"), (0, 1, "pure")]:
    c = [r for r in rows if lo <= r["staff_groups"] <= hi and r["w"] > 600]
    if not c:
        continue
    for r in random.sample(c, min(2, len(c))):
        o = export(r["dir"], f"{tag}_{r['staff_groups']}")
        print(f"{tag} 组数={r['staff_groups']} -> {o}   {r['dir'][:40]}")
