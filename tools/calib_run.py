# -*- coding: utf-8 -*-
"""标定: 用"最长连续暗段占页宽比例" 与 "长段行数" 能否分开纯简谱/五线谱。
五线谱的谱线被小节线打断 -> 单行最长段只有 30-40% 页宽, 55% 的阈值会漏。
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

def prof(path, frac=0.30):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    thr = max(60, int(g.mean()) - 25)
    c = g < thr
    W = c.shape[1]
    best = 0
    n30 = n55 = 0
    for y in range(c.shape[0]):
        row = c[y]
        if not row.any():
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        st = np.where(d == 1)[0]
        en = np.where(d == -1)[0]
        L = int((en - st).max())
        best = max(best, L)
        if L >= 0.30 * W:
            n30 += 1
        if L >= 0.55 * W:
            n55 += 1
    return 100.0 * best / W, n30, n55

CASES = [
    ("丁小琴编-19打起手鼓唱起歌（正谱）__qupu123-325175", "非纯(五线谱!)"),
    ("夜空中最亮的星（五线谱）__qupu123-333873", "非纯(五线谱)"),
    ("我喜欢__jianpucn-29936", "非纯(淡钢琴谱)"),
    ("陈奕迅-十年__jianpucn-95881", "非纯(吉他)"),
    ("最佳损友__jianpucn-456171", "非纯(吉他)"),
    ("K歌之王__jianpucn-40413", "纯"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯"),
    ("去看拉萨河__qupu123-395689", "纯(密集)"),
    ("恋着多喜欢__jianpucn-88791", "纯(带照片)"),
    ("卖报歌简谱_儿歌_冲击你的儿时记忆-简谱__jianpujia-15680", "纯"),
]
print(f"{'样本':<34}{'类型':<16}{'最长段%':>8}{'长段行30%':>10}{'长段行55%':>10}")
for t, kind in CASES:
    g0 = glob.glob("images-prep/*/" + glob.escape(t))
    if not g0:
        print(f"{t[:32]:<34}{kind:<16} 找不到")
        continue
    p = BT.pick_page(g0[0])
    if not p:
        continue
    try:
        a, b, c = prof(p)
    except Exception as e:
        print(f"{t[:32]:<34}{kind:<16} 读不出 {type(e).__name__}")
        continue
    print(f"{t[:32]:<34}{kind:<16}{a:>8.1f}{b:>10}{c:>10}")
