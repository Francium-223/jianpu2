# -*- coding: utf-8 -*-
"""检测"调号行泄漏修复"会影响的老谱: 前两个被接受的行带里, 有一个的"像数字的连通域"
少于 4 个 —— 这类行带以前会贡献垃圾 token(`1 - - - 'x`), 现在会被丢掉, 故需重转。
纯几何, 不占 GPU。输出 train-work/headfix_sheets.txt
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

def digitlike(c):
    # 与 crop_note_regions 的数字判据一致
    return c[5] >= 14 and c[5] <= 45 and c[5] > c[4] and c[4] >= 3 and c[5] < 3.5 * c[4]

def affected(page):
    im = Image.open(page).convert("L")
    if im.width > 2000:
        im = im.resize((2000, max(1, int(round(im.height * 2000 / im.width)))), Image.LANCZOS)
    elif im.width < 700:
        im = im.resize((1200, max(1, int(round(im.height * 1200 / im.width)))), Image.LANCZOS)
    content = np.asarray(im) < T.TOL
    acc = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        for s, e in T.split_row_inner(content, s0, e0):
            sub = content[s:e + 1]
            st, hl = T.strip_hlines(sub)
            cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
            if not cs:
                continue
            t115 = [c for c in cs if c[5] >= 1.15 * c[4]]
            nl = sum(1 for x in hl if x[4] >= 8)
            fr = len(t115) / len(cs)
            if fr >= 0.85 or (len(t115) >= 6 and nl >= 1):
                nd = sum(1 for c in T.components(st) if digitlike(c))
                acc.append(nd)
    if len(acc) < 2:
        return False
    return acc[0] < 4 or acc[1] < 4

dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
# 只查非 jianpucn-pop(那个整源都会重转)
dirs = [d for d in dirs if "jianpucn-pop" not in d]
print(f"检查老源 {len(dirs)} 个")
hits = []
for i, d in enumerate(dirs):
    # 只查已有结果的(没转过的不需要"重"转)
    nm = BT.safe_name(os.path.basename(d))
    if not os.path.exists(f"batch-out/{nm}.txt"):
        continue
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        if affected(p):
            hits.append(os.path.basename(d.rstrip("/\\")))
    except Exception:
        pass
    if (i + 1) % 500 == 0:
        print(f"  {i+1}/{len(dirs)}  命中 {len(hits)}", flush=True)
print(f"受影响(需重转) {len(hits)}")
with open("train-work/headfix_sheets.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(hits))
