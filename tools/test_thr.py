# -*- coding: utf-8 -*-
"""测自适应灰度阈值能否抓住"淡扫描件"的谱线。
固定 128 对淡扫描件失效(实测《我喜欢》是钢琴五线谱却 nline=0 wide=4 混过过滤器)。
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

def feats(path, mode):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    if mode == "fix":
        thr = 128
    else:
        thr = max(60, int(g.mean()) - 25)
    c = g < thr
    W = c.shape[1]
    rs = c.sum(axis=1)
    nline = 0
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        if len(st) and (en - st).max() >= 0.55 * W:
            nline += 1
    return nline, int((rs > 0.60 * W).sum()), int(g.mean()), thr

CASES = [
    ("我喜欢__jianpucn-29936", "非纯(钢琴五线谱,淡)"),
    ("消失的爱__jianpucn-135743", "非纯(待定)"),
    ("K歌之王__jianpucn-40413", "纯"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯"),
    ("去看拉萨河__qupu123-395689", "纯(密集)"),
    ("最佳损友__jianpucn-456171", "非纯(吉他)"),
    ("一切还好__jianpucn-8758", "非纯(吉他)"),
]
print(f"{'样本':<40}{'固定128':>14}{'自适应':>16}{'均值':>6}")
for t, kind in CASES:
    g = glob.glob("images-prep/*/" + glob.escape(t))
    if not g:
        print(f"{t[:38]:<40} 找不到")
        continue
    p = BT.pick_page(g[0])
    try:
        a = feats(p, "fix")
        b = feats(p, "adap")
    except Exception as e:
        print(f"{t[:38]:<40} 读不出 {type(e).__name__}")
        continue
    print(f"{t[:26]:<28}{kind[:10]:<12} nl{a[0]:>3} w{a[1]:>3}   nl{b[0]:>3} w{b[1]:>3}   {b[2]:>4}")
