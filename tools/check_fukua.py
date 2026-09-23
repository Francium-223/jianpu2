# -*- coding: utf-8 -*-
"""逐个检查所有《浮夸》转写, 找出真含查询旋律的那一个, 并导出原谱。"""
import glob, io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
from PIL import Image
import batch_transcribe as BT

NOTE = re.compile(r"^[,']*[qsdhc]*[,']*([1-7])")
q = "11176371117675"

for f in sorted(glob.glob("batch-out/*.txt")):
    if "浮夸" not in f:
        continue
    d = io.open(f, encoding="utf-8").read().split()
    digs = "".join(NOTE.match(t).group(1) for t in d if NOTE.match(t))
    if len(digs) < len(q):
        print(f"  {os.path.basename(f)[:52]:54s} {len(digs):4d} 音  (太短)")
        continue
    best = None
    for i in range(len(digs) - len(q) + 1):
        w = digs[i:i + len(q)]
        diff = sum(1 for a, b in zip(w, q) if a != b)
        if best is None or diff < best[0]:
            best = (diff, i, w)
    flag = "★命中" if best[0] <= 1 else "  "
    print(f"{flag} {os.path.basename(f)[:52]:54s} {len(digs):4d} 音  最近差{best[0]}处 @{best[1]}  {best[2]}")
    if best[0] <= 1:
        # 导出该谱的原图
        name = os.path.basename(f)[:-4]
        key = re.sub(r"[（(].*?[)）]", "", name).split("__")[0].strip()[:12]
        for dirp in glob.glob("images-prep/*/*"):
            bn = os.path.basename(dirp)
            if key and key in bn:
                p = BT.pick_page(dirp)
                if p:
                    im = Image.open(p).convert("RGB")
                    if im.width > 900:
                        im = im.resize((900, int(im.height * 900 / im.width)), Image.LANCZOS)
                    out = "train-work/浮夸_原谱.png"
                    im.save(out)
                    print(f"    原谱: {bn[:56]}/{os.path.basename(p)}")
                    print(f"    导出: {out} {im.size}")
                break
