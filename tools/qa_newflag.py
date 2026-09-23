# -*- coding: utf-8 -*-
"""导出"自适应 nline>=5 但固定阈值下 nline<5"且已转出>=50 音符的谱图, 供肉眼判断。
这些是自适应阈值新抓的, 最可能是误杀。
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

def nline(path, adaptive):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    thr = max(60, int(g.mean()) - 25) if adaptive else 128
    W = g.shape[1]
    c = g < thr
    n = 0
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        if len(st) and (en - st).max() >= 0.55 * W:
            n += 1
    return n

rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
cand = []
for r in rows:
    if int(r["nline"]) < 5:
        continue
    nm = BT.safe_name(r["dir"])
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        g2 = glob.glob("batch-out/*" + r["dir"][-10:] + ".txt")
        f = g2[0] if g2 else None
    if not f or not os.path.exists(f):
        continue
    t = open(f, encoding="utf-8").read().split()
    d = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    if d < 50:
        continue
    g3 = glob.glob("images-prep/*/" + glob.escape(r["dir"]))
    if not g3:
        continue
    p = BT.pick_page(g3[0])
    if not p:
        continue
    try:
        n_fix = nline(p, False)
        n_ad = nline(p, True)
    except Exception:
        continue
    if n_fix >= 5:
        continue          # 固定阈值下也判非纯 -> 本来就会移出, 不是新增误杀
    cand.append((n_ad, n_fix, d, r["dir"]))

cand.sort(reverse=True)
print(f"自适应新增、且已转出>=50 音符的: {len(cand)} 个")
for n_ad, n_fix, d, name in cand[:8]:
    print(f"  音符{d:4d} 自适应nl={n_ad:>3} 固定nl={n_fix:>3}  {name[:46]}")
for i, (n_ad, n_fix, d, name) in enumerate(cand[:3]):
    g3 = glob.glob("images-prep/*/" + glob.escape(name))
    p = BT.pick_page(g3[0])
    im = Image.open(p).convert("RGB")
    if im.width > 800:
        im = im.resize((800, int(im.height * 800 / im.width)), Image.LANCZOS)
    if im.height > 1300:
        im = im.crop((0, 0, im.width, 1300))
    im.save(f"train-work/qa_new_{i}.png")
    print(f"  导出 train-work/qa_new_{i}.png <- {name[:38]}")
