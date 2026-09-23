# -*- coding: utf-8 -*-
"""QA: 找出"被判纯简谱却转出 0 音符"的谱 —— 这些是转写失败(纯简谱本该有音符)。
纯简谱的空结果通常有原因: 伴奏谱/只有歌词/图太小。抽样导出供肉眼判断。
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT
from PIL import Image

kind = {r["dir"]: r for r in csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t")}
empty_pure = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b in ("progress.txt", "skipped.txt"):
        continue
    t = open(f, encoding="utf-8").read().split()
    d = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    if d > 0:
        continue
    # 找回目录名(反查 kind2)
    hit = None
    for dn, r in kind.items():
        if BT.safe_name(dn) == b[:-4] or dn[-10:] in b:
            hit = r
            break
    if hit and hit["pure"] == "1":
        empty_pure.append((dn, hit["nline"], hit["w"], hit["h"]))

print(f"纯简谱却 0 音符: {len(empty_pure)} 个")
small = sum(1 for _, _, w, h in empty_pure if int(w) < 700)
print(f"  其中宽度<700(小图): {small}")
for dn, nl, w, h in empty_pure[:12]:
    print(f"  {w}x{h} nl={nl:>3}  {dn[:52]}")
for i, (dn, nl, w, h) in enumerate(empty_pure[:3]):
    g = glob.glob("images-prep/*/" + glob.escape(dn))
    if not g:
        continue
    p = BT.pick_page(g[0])
    if not p:
        continue
    try:
        im = Image.open(p).convert("RGB")
        if im.width > 780:
            im = im.resize((780, int(im.height * 780 / im.width)), Image.LANCZOS)
        if im.height > 1200:
            im = im.crop((0, 0, im.width, 1200))
        im.save(f"train-work/qa_empty_{i}.png")
        print(f"  导出 train-work/qa_empty_{i}.png <- {dn[:40]}")
    except Exception as e:
        print(f"  导出失败 {type(e).__name__}")
