# -*- coding: utf-8 -*-
"""抽查: 找一个带 ~ 的谱, 看标记处的音符在原图上是否真有连音线。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image

# 找第一个含 ~ 的谱
pick = None
for f in sorted(glob.glob("batch-out/*.txt")):
    if os.path.basename(f) in ("progress.txt", "skipped.txt"):
        continue
    toks = open(f, encoding="utf-8").read().split()
    if "~" in toks:
        pick = (f, toks)
        break
if not pick:
    print("还没有带 ~ 的谱")
    sys.exit(0)
f, toks = pick
name = os.path.basename(f)[:-4]
print("样本:", name[:60])
i = toks.index("~")
print("~ 前后:", " ".join(toks[max(0, i - 6):i + 7]))

# 找对应目录与图
cands = glob.glob("images-prep/*/*")
d = None
for c in cands:
    if os.path.basename(c).startswith(name[:40]):
        d = c
        break
if not d:
    print("找不到原图目录")
    sys.exit(0)
import batch_transcribe as BT
p = BT.pick_page(d)
im = Image.open(p).convert("RGB")
print("原图:", os.path.basename(p), im.size)
# 整页缩小看一眼
if im.width > 900:
    im2 = im.resize((900, int(im.height * 900 / im.width)), Image.LANCZOS)
else:
    im2 = im
im2.save("train-work/qa_marker.png")
print("导出 train-work/qa_marker.png", im2.size)
