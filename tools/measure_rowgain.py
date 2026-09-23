# -*- coding: utf-8 -*-
"""量化"简谱行提取"的价值: 被纯度门拒掉的谱里, 有多少其实含可用的简谱行?

判据(纯几何, 不加载模型): 对图片跑行带切分 + 音符块切分, 若**存在某一行带**
包含 >= 10 个"像音符"的块, 则这一页含可转写的简谱行。
"""
import glob
import os
import random
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

SAMPLE = int(sys.argv[1]) if len(sys.argv) > 1 else 120


def jianpu_rows(img_path):
    """返回 (行带总数, 像简谱的行带数, 最大音符块数)"""
    im = Image.open(img_path).convert("L")
    if im.width > 2000:
        im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
    elif im.width < 950:
        im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
    c = np.asarray(im) < T.TOL
    nband = nrow = mx = 0
    for s, e in T.fine_rows(c, T.ROW_GAP):
        sub = c[s:e + 1]
        regs = T.crop_note_regions(sub)
        # 只数"像音符"的块: 瘦高且高度在 12-45
        st, _hl = T.strip_hlines(sub)
        cs = [x for x in T.components(st) if 12 <= x[5] <= 45 and x[4] >= 3]
        tall = [x for x in cs if x[5] >= 1.15 * x[4]]
        nband += 1
        if len(tall) >= 10:
            nrow += 1
            mx = max(mx, len(tall))
    return nband, nrow, mx


def src_of(name):
    """batch-out-bad 里的 txt 名 -> images-prep 下的图"""
    for d in glob.glob("images-prep/*/*"):
        if os.path.isdir(d) and os.path.basename(d)[:40] and \
           BT.safe_name(os.path.basename(d)) == name:
            return BT.pick_page(d)
    return None


bad = [os.path.basename(f)[:-4] for f in glob.glob("batch-out-bad/*.txt")]
random.seed(7)
random.shuffle(bad)
bad = bad[:SAMPLE]
print(f"抽检 batch-out-bad 里 {len(bad)} 个被拒的谱")

have_row = 0
checked = 0
for i, name in enumerate(bad, 1):
    p = src_of(name)
    if not p:
        continue
    try:
        nb, nr, mx = jianpu_rows(p)
    except Exception:
        continue
    checked += 1
    if nr > 0:
        have_row += 1
    if i % 30 == 0:
        print(f"  已查 {checked}, 含简谱行 {have_row}", flush=True)

print(f"\n实际检查 {checked} 个")
if checked:
    print(f"  含 >=1 个'像简谱行'的: {have_row} ({100*have_row/checked:.0f}%)")
    print(f"  => 若实现行级提取, 这批被拒的谱里约 {100*have_row/checked:.0f}% 可以救回来")
