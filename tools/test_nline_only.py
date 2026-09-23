# -*- coding: utf-8 -*-
"""验证: 只用"自适应阈值的 nline"能否分开纯/非纯(不靠 wide —— 它会被照片骗)。
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

def nline_adaptive(path):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    thr = max(60, int(g.mean()) - 25)
    W = g.shape[1]
    c = g < thr
    n = 0
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        if len(st) and (en - st).max() >= 0.55 * W:
            n += 1
    return n

CASES = [
    ("K歌之王__jianpucn-40413", "纯"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯"),
    ("去看拉萨河__qupu123-395689", "纯(密集)"),
    ("恋着多喜欢__jianpucn-88791", "纯(带照片!)"),
    ("想你想你我想你__jianpucn-233269", "纯(待定)"),
    ("无声的雨__jianpucn-936", "纯(待定)"),
    ("八个娃娃__jianpucn-42605", "纯(待定)"),
    ("我喜欢__jianpucn-29936", "非纯(淡钢琴谱)"),
    ("消失的爱__jianpucn-135743", "非纯(待定)"),
    ("一切还好__jianpucn-8758", "非纯(吉他)"),
    ("淘汰__jianpucn-2971", "非纯(吉他)"),
    ("老公老公我爱你__jianpucn-86799", "非纯(吉他)"),
    ("最佳损友__jianpucn-456171", "非纯(吉他)"),
    ("第一次__jianpucn-87448", "非纯(吉他)"),
]
print(f"{'样本':<30}{'类型':<16}{'自适应nline':>12}")
for t, kind in CASES:
    g = glob.glob("images-prep/*/" + glob.escape(t))
    if not g:
        print(f"{t[:28]:<30}{kind:<16} 找不到")
        continue
    p = BT.pick_page(g[0])
    try:
        n = nline_adaptive(p)
    except Exception:
        print(f"{t[:28]:<30}{kind:<16} 读不出")
        continue
    print(f"{t[:28]:<30}{kind:<16}{n:>12}")
