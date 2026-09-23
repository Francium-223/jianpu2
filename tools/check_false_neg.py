# -*- coding: utf-8 -*-
"""查"纯简谱门"的漏检(假阴性): 被判为纯(nline<5)但其实是吉他混合谱的。
用 v1 特征交叉验证 —— 灰度<128 且横向覆盖>60%页宽 的行数(吉他/五线谱会很高)。
输出 train-work/fn_sheets.txt (可疑漏检名单)
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
pure = [r["dir"] for r in rows if r["pure"] == "1"]
print(f"被判为纯简谱的 {len(pure)} 个, 逐个用 v1 特征复核")

def v1(path):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im)
    W = g.shape[1]
    c = g < 128
    rs = c.sum(axis=1)
    return int((rs > 0.60 * W).sum())

sus = []
for i, d in enumerate(pure):
    g = glob.glob("images-prep/*/" + glob.escape(d))
    if not g:
        continue
    p = BT.pick_page(g[0])
    if not p:
        continue
    try:
        n = v1(p)
    except Exception:
        continue
    if n >= 20:
        # 有没有转出内容(污染)？
        nm = BT.safe_name(d)
        f = f"batch-out/{nm}.txt"
        nd = None
        if os.path.exists(f):
            t = open(f, encoding="utf-8").read().split()
            nd = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        sus.append((n, d, nd))
    if (i + 1) % 1000 == 0:
        print(f"  {i+1}/{len(pure)}  可疑 {len(sus)}", flush=True)

sus.sort(reverse=True)
print(f"\n可疑漏检 {len(sus)} 个 (v1>=20 但被判纯)")
print(f"  其中已转出音符的(真污染): {sum(1 for _,_,nd in sus if nd and nd>=10)}")
print(f"  污染音符合计: {sum(nd or 0 for _,_,nd in sus)}")
for n, d, nd in sus[:15]:
    print(f"    v1={n:3d}  音符={nd if nd is not None else '未转'}  {d[:44]}")
with open("train-work/fn_sheets.txt", "w", encoding="utf-8") as f:
    for n, d, nd in sus:
        f.write(f"{d}\t{n}\t{nd if nd is not None else ''}\n")
