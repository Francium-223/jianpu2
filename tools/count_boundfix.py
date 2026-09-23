# -*- coding: utf-8 -*-
"""统计: 新的"谱头边界"判据(加了下划线>=6)相对旧判据, 会让多少张谱多转出内容。
= 在 [旧边界, 新边界) 区间内存在"宽松阈值下可通过"的行带 的谱数。"""
import glob, json, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

def feats(page):
    im = Image.open(page).convert("L")
    if im.width > 2000:
        im = im.resize((2000, max(1, int(round(im.height * 2000 / im.width)))), Image.LANCZOS)
    arr = np.asarray(im); content = arr < T.TOL
    out = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        for s, e in T.split_row_inner(content, s0, e0):
            sub = content[s:e + 1]
            st, hl = T.strip_hlines(sub)
            cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
            t4 = sum(1 for c in cs if c[5] >= 1.4 * c[4])
            t115 = sum(1 for c in cs if c[5] >= 1.15 * c[4])
            nl = sum(1 for h in hl if h[4] >= 8)
            out.append((len(cs), t4, t115, nl))
    return out

def bound(bs, use_nl):
    for i, (n, t4, t115, nl) in enumerate(bs):
        if n >= 15:
            fr4 = t4 / n if n else 0
            if fr4 >= 0.40 or (use_nl and nl >= 6):
                return i
    return -1

def ok(n, t, nl):
    fr = (t / n) if n else 0.0
    return fr >= 0.85 or (t >= 6 and nl >= 1)

ranked = sorted(glob.glob("rank-out/ranked*.jsonl"))
rows = []
for rf in ranked:
    for l in open(rf, encoding="utf-8"):
        try:
            rows.append(json.loads(l))
        except Exception:
            pass
rows.sort(key=lambda r: r.get("play", 0), reverse=True)
seen, dirs = set(), []
for r in rows:
    d = os.path.dirname(r["img"])
    if d in seen:
        continue
    seen.add(d)
    dirs.append(d)
dirs = dirs[:1531]

n_aff = n_chk = 0
_aff = []
for d in dirs:
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        bs = feats(p)
    except Exception:
        continue
    if not bs:
        continue
    n_chk += 1
    bo, bn = bound(bs, False), bound(bs, True)
    if bo == bn:
        continue
    lo, hi = (bo, bn) if bn > bo else (bn, bo)
    # 区间内是否有"旧判据下用严格阈值被拒、新判据下用宽松阈值可通过"的行带
    if any(ok(n, t115, nl) and not ok(n, t4, nl) for (n, t4, t115, nl) in bs[lo:hi]):
        n_aff += 1
        _aff.append(os.path.basename(d.rstrip("/\\")))
print(f"检查 {n_chk} 谱; 受本次边界修正影响的谱: {n_aff}")
with open("train-work/boundfix_sheets.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(_aff))
print("名单已存 train-work/boundfix_sheets.txt")
