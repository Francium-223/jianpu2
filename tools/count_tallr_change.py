# -*- coding: utf-8 -*-
"""只读统计: 对比"旧逻辑(全文 1.4)" vs "新逻辑(谱头1.4/正文1.15)" 下接受的行带集合,
算出有多少谱会因此改变 —— 即本次重跑真正能补回内容的谱数。"""
import glob, json, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

def bands_of(page):
    arr = np.asarray(Image.open(page).convert("L"))
    content = arr < T.TOL
    st, sc = None, None
    # 与 _load_gray 一致: 过宽页先归一化
    if arr.shape[1] > 2000:
        from PIL import Image as I
        im = Image.open(page).convert("L")
        w, h = im.size
        im = im.resize((2000, max(1, int(round(h * 2000 / w)))), I.LANCZOS)
        arr = np.asarray(im); content = arr < T.TOL
    out = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        for s, e in T.split_row_inner(content, s0, e0):
            sub = content[s:e + 1]
            stp, hl = T.strip_hlines(sub)
            cs = [c for c in T.components(stp) if 10 <= c[5] <= 50 and c[4] >= 4]
            tl4 = [c for c in cs if c[5] >= 1.4 * c[4]]
            tl115 = [c for c in cs if c[5] >= 1.15 * c[4]]
            nl = sum(1 for h in hl if h[4] >= 8)
            out.append((s, e, len(cs), len(tl4), len(tl115), nl))
    return out

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

n_changed = 0
n_checked = 0
for d in dirs:
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        bs = bands_of(p)
    except Exception:
        continue
    if not bs:
        continue
    n_checked += 1
    def acc(n, t, nl, R):
        fr = (t / n) if n else 0.0
        return fr >= 0.85 or (t >= 6 and nl >= 1)
    old = sum(1 for (_s, _e, n, t4, t115, nl) in bs if acc(n, t4, nl, 1.4))
    # 新逻辑: 谱头边界 = 第一个 n>=15 且 严格frac>=0.40 的行带
    hu = -1
    for i, (_s, _e, n, t4, t115, nl) in enumerate(bs):
        fr4 = (t4 / n) if n else 0.0
        if n >= 15 and fr4 >= 0.40:
            hu = i
            break
    new = 0
    for i, (_s, _e, n, t4, t115, nl) in enumerate(bs):
        R = t4 if (0 <= i < hu) else t115
        if acc(n, R, nl, 0):
            new += 1
    if new != old:
        n_changed += 1
print(f"检查 {n_checked} 谱; 接受行带数发生变化的谱: {n_changed}")
with open("train-work/tallr_changed.txt", "w", encoding="utf-8") as g:
    g.write(f"{n_changed}\n")
