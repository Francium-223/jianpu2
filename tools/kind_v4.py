# -*- coding: utf-8 -*-
"""纯简谱检测 v4: 每行求"最长连续暗段", 谱线(五线谱/六线谱)会给出接近整页宽的长段;
简谱的圆滑线/延音线是弧, 单行里的连续段短得多。
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

def longest_run(row):
    """一维布尔数组里最长连续 True 的长度。"""
    if not row.any():
        return 0
    # 用差分找连续段
    d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
    starts = np.where(d == 1)[0]
    ends = np.where(d == -1)[0]
    return int((ends - starts).max()) if len(starts) else 0

def feats(path, thr=128):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 700 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im)
    W = g.shape[1]
    c = g < thr
    n_long = 0            # 最长连续段 >= 35% 页宽 的行数
    n_vlong = 0           # >= 55% 页宽
    for y in range(c.shape[0]):
        L = longest_run(c[y])
        if L >= 0.35 * W:
            n_long += 1
        if L >= 0.55 * W:
            n_vlong += 1
    return n_long, n_vlong, W

SAMPLES = [
    ("K歌之王__jianpucn-40413", "纯"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯"),
    ("去看拉萨河__qupu123-395689", "纯(密)"),
    ("红星歌简谱___传唱红星歌_重走红军路__jianpujia-15449", "纯?"),
    ("第一次__jianpucn-87448", "吉他"),
    ("富士山下 （ C调原版编配）__jianpucn-457736", "吉他"),
    ("最佳损友__jianpucn-456171", "吉他"),
    ("-任我行__jianpucn-240540", "吉他"),
    ("爱情转移(富士山下)__jianpucn-118124", "吉他"),
    ("夜空中最亮的星（五线谱）__qupu123-333873", "五线谱"),
    ("童话总谱__jianpucn-102669", "总谱"),
]
for d, kind in SAMPLES:
    g = glob.glob("images-prep/*/" + glob.escape(d))
    if not g:
        print(f"{d[:32]:34s} 找不到"); continue
    p = BT.pick_page(g[0])
    if not p:
        continue
    a, b, W = feats(p)
    print(f"{d[:32]:34s} [{kind:6s}] 长段>=35%宽: {a:3d}   >=55%宽: {b:3d}   (页宽{W})")
