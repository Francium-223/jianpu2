# -*- coding: utf-8 -*-
"""统计: h_ref 改用按行带阈值(_R) 后, 有多少张谱的高度门会放宽(即原本被杀掉的真数字)。
判据: 某个被接受的行带里, 存在高度介于 0.8*h_ref_new 与 0.8*h_ref_old 之间的连通域。"""
import glob, json, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

def inspect(page):
    im = Image.open(page).convert("L")
    if im.width > 2000:
        im = im.resize((2000, max(1, int(round(im.height * 2000 / im.width)))), Image.LANCZOS)
    arr = np.asarray(im); content = arr < T.TOL
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    feats = []
    for s, e in bands:
        sub = content[s:e + 1]
        st, hl = T.strip_hlines(sub)
        cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
        t4 = [c for c in cs if c[5] >= 1.4 * c[4]]
        t115 = [c for c in cs if c[5] >= 1.15 * c[4]]
        nl = sum(1 for h in hl if h[4] >= 8)
        feats.append((len(cs), t4, t115, nl))
    # 谱头边界
    hu = -1
    for i, (n, t4, t115, nl) in enumerate(feats):
        if n >= 15 and ((len(t4) / n) >= 0.40 or nl >= 6):
            hu = i
            break
    for i, (s, e) in enumerate(bands):
        if i >= hu and hu >= 0:
            R = 1.15
        elif hu < 0:
            R = 1.15
        else:
            R = 1.4
        sub = content[s:e + 1]
        st, _ = T.strip_hlines(sub)
        cs2 = [c for c in T.components(st) if 10 <= c[5] <= 45 and c[4] >= 3]
        n, t4, t115, nl = feats[i]
        fr = (len(t115) / n) if n else 0.0
        if not (fr >= 0.85 or (len(t115) >= 6 and nl >= 1)):
            continue
        ta = [c[5] for c in cs2 if c[5] >= 1.4 * c[4]]
        tb = [c[5] for c in cs2 if c[5] >= R * c[4]]
        if not ta or not tb:
            continue
        ta.sort(); tb.sort()
        ho = ta[len(ta) // 2]
        hn = tb[len(tb) // 2]
        if ho == hn:
            continue
        g_old, g_new = 0.8 * ho, 0.8 * hn
        if any(g_new <= c[5] < g_old for c in cs2):
            return True
    return False

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

aff = []
for d in dirs:
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        if inspect(p):
            aff.append(os.path.basename(d.rstrip("/\\")))
    except Exception:
        pass
print(f"h_ref 修复影响的谱: {len(aff)} / {len(dirs)}")
with open("train-work/href_sheets.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(aff))
print("名单: train-work/href_sheets.txt")
