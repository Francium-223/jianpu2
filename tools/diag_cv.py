# -*- coding: utf-8 -*-
"""跨多张谱: 行带特征 frac / CV / ±12%中位数占比, 找区分"文字行 vs 音符行/粘连行带"的判据。"""
import os, statistics, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T

SHEETS = [
    ("友谊天长地久", r"images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003__pg0.jpg"),
    ("幸福花园", r"images-prep/qupu123-crawl/11幸福花园（双谱）__qupu123-312866/002.jpg"),
    ("歌唱春天", r"images-prep/qupu123-crawl/12歌唱春天（双谱）__qupu123-316431/002.jpg"),
    ("奋发向上", r"images-prep/qupu123-crawl/奋发向上__qupu123-327224/003.jpg"),
    ("BlueBerry", r"images-prep/qupu123-crawl/Blue_Berry_Hill_鸟饭树山（蓝莓山）__qupu123-375493/002__pg0.jpg"),
]
if not os.path.exists(SHEETS[0][1]):
    import batch_transcribe as BT
    BT.split_pages(r"images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003.jpg")

for name, page in SHEETS:
    if not os.path.exists(page):
        print(f"### {name}: 缺页")
        continue
    arr = np.asarray(Image.open(page).convert("L"))
    content = arr < T.TOL
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    print(f"\n######## {name} ########")
    for s, e in bands:
        sub = content[s:e + 1]
        stripped, hlines = T.strip_hlines(sub)
        cs = [c for c in T.components(stripped) if 10 <= c[5] <= 50 and c[4] >= 4]
        tall = [c for c in cs if c[5] >= 1.4 * c[4]]
        if not cs:
            continue
        frac = len(tall) / len(cs)
        hs = [c[5] for c in tall]
        med = statistics.median(hs) if hs else 0
        cv = (statistics.pstdev(hs) / med) if hs and med else 0.0
        unif = (sum(1 for h in hs if abs(h - med) <= 0.12 * med) / len(hs)) if hs else 0.0
        nl = sum(1 for h in hlines if h[4] >= 8)
        old = frac >= 0.85 or (len(tall) >= 6 and nl >= 1)
        newA = frac >= 0.85 or (len(tall) >= 6 and nl >= 1 and cv <= 0.20)
        newB = frac >= 0.85 or (len(tall) >= 6 and nl >= 1 and unif >= 0.72)
        print(f"  y={s:4d}-{e:4d} h={e-s+1:3d} n={len(cs):3d} tall={len(tall):3d} "
              f"frac={frac:.2f} CV={cv:.2f} 均匀={unif:.2f} 横线={nl:2d}  "
              f"旧={'收' if old else '丢'} A={'收' if newA else '丢'} B={'收' if newB else '丢'}")
