# -*- coding: utf-8 -*-
"""抽样: 靠 wide 判非纯、且已转出较多音符的谱 —— 它们最可能是"误杀", 必须看图确认。
导出前 4 张图供肉眼检查。
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
cand = []
for r in rows:
    if r["pure"] != "0" or int(r["wide"]) < 45 or int(r["nline"]) >= 5:
        continue
    nm = BT.safe_name(r["dir"])
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        g = glob.glob("batch-out/*" + r["dir"][-10:] + ".txt")
        f = g[0] if g else None
    if not f or not os.path.exists(f):
        continue
    t = open(f, encoding="utf-8").read().split()
    d = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    if d >= 50:
        cand.append((d, r["nline"], r["wide"], r["dir"]))
cand.sort(reverse=True)
print(f"靠 wide 抓、且已转出>=50 音符的: {len(cand)} 个")
for d, nl, wd, name in cand[:10]:
    print(f"  音符{d:4d} nl={nl:>3} wide={wd:>3}  {name[:50]}")
for i, (d, nl, wd, name) in enumerate(cand[:4]):
    g = glob.glob("images-prep/*/" + glob.escape(name))
    if not g:
        continue
    p = BT.pick_page(g[0])
    if not p:
        continue
    try:
        im = Image.open(p).convert("RGB")
        if im.width > 800:
            im = im.resize((800, int(im.height * 800 / im.width)), Image.LANCZOS)
        if im.height > 1400:
            im = im.crop((0, 0, im.width, 1400))
        im.save(f"train-work/qa_wide_{i}.png")
        print(f"  导出 train-work/qa_wide_{i}.png  <- {name[:40]}")
    except Exception as e:
        print(f"  导出失败 {type(e).__name__}")
