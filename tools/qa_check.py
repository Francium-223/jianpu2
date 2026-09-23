# -*- coding: utf-8 -*-
"""抽查转写正确性: 导出某首的谱图(放大)+ 它的 token, 供人眼比对。

用法:
  py tools/qa_check.py --pick qupu123 jianpujia jianpucn    # 每个源挑一首
  py tools/qa_check.py <batch-out里的txt名>
  py tools/qa_check.py <txt名> --rows 2                      # 只看前 2 个行带
"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image
import numpy as np
import transcribe as T
import batch_transcribe as BT

OUT = "train-work/qa"
os.makedirs(OUT, exist_ok=True)


def find_dir(name):
    """batch-out 的 txt 名 -> images-prep 下的目录"""
    for d in glob.glob("images-prep/*/*"):
        if os.path.isdir(d) and BT.safe_name(os.path.basename(d)) == name:
            return d
    return None


def show(name, rows=2, zoom=2):
    txt = os.path.join("batch-out", name + ".txt")
    if not os.path.exists(txt):
        print(f"  {name}: 没有转写结果")
        return
    toks = io.open(txt, encoding="utf-8").read().split()
    d = find_dir(name)
    if not d:
        print(f"  {name}: 找不到源图目录")
        return
    p = BT.pick_page(d)
    im = Image.open(p).convert("RGB")
    # 按流程同样的方式归一化宽度, 再裁前几个行带
    if im.width > 2000:
        im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
    elif im.width < 950:
        im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
    g = np.asarray(im.convert("L")) < T.TOL
    bands = list(T.fine_rows(g, T.ROW_GAP))
    if bands:
        y1 = bands[min(rows, len(bands)) - 1][1]
        crop = im.crop((0, 0, im.width, min(im.height, y1 + 10)))
    else:
        crop = im.crop((0, 0, im.width, im.height // 3))
    if zoom != 1:
        crop = crop.resize((int(crop.width * zoom), int(crop.height * zoom)), Image.LANCZOS)
    # 图太大就再缩到 1400 宽以内, 免得看不清
    if crop.width > 1400:
        crop = crop.resize((1400, int(crop.height * 1400 / crop.width)), Image.LANCZOS)
    out = os.path.join(OUT, BT.safe_name(name)[:48] + ".png")
    crop.save(out)
    print(f"\n=== {name} ===")
    print(f"  源图 {im.size}  行带 {len(bands)} 个  导出 {out} ({crop.size})")
    print(f"  token 共 {len(toks)} 个")
    print("  前 60 个: " + " ".join(toks[:60]))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--pick" in sys.argv:
        for src in args:
            cands = [os.path.basename(f)[:-4] for f in glob.glob(f"batch-out/*{src}*.txt")]
            cands = [c for c in cands if c not in ("progress", "skipped")]
            for c in cands[:24]:
                if len(io.open(f"batch-out/{c}.txt", encoding="utf-8").read().split()) > 60:
                    show(c)
                    break
    else:
        for a in args:
            show(a)
