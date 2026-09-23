# -*- coding: utf-8 -*-
"""纯简谱检测 v3: 用宽松灰度阈值捕捉"淡谱线"(六线谱常印得很浅), 统计
横向覆盖率高的行数。先在已知样本上验证。
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import batch_transcribe as BT

def feats(path):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 700 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    g = np.asarray(im).astype(np.int16)
    H, W = g.shape
    out = {}
    for thr, name in ((160, "lo"), (128, "mid"), (100, "hi")):
        c = g < thr
        rs = c.sum(axis=1)
        out["rows_" + name] = int((rs > 0.35 * W).sum())   # 横向覆盖 >35% 的行
        out["rows" + name + "_60"] = int((rs > 0.60 * W).sum())
    out["ink"] = round(float((g < 160).mean()), 4)
    out["w"], out["h"] = W, H
    return out

SAMPLES = [
    ("K歌之王__jianpucn-40413", "纯简谱"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯简谱?"),
    ("爱情转移(富士山下)__jianpucn-118124", "吉他混合"),
    ("最佳损友__jianpucn-456171", "吉他混合"),
    ("第一次__jianpucn-87448", "吉他混合"),
    ("夜空中最亮的星（五线谱）__qupu123-333873", "纯五线谱"),
    ("童话总谱__jianpucn-102669", "总谱"),
    ("-任我行__jianpucn-240540", "吉他(0音符)"),
    ("富士山下 （ C调原版编配）__jianpucn-457736", "吉他混合"),
]
for d, kind in SAMPLES:
    g = glob.glob("images-prep/*/" + glob.escape(d))
    if not g:
        print(f"{d[:34]:36s} 找不到"); continue
    p = BT.pick_page(g[0])
    if not p:
        print(f"{d[:34]:36s} 无页"); continue
    f = feats(p)
    print(f"{d[:32]:34s} [{kind:8s}] 覆盖>35%: 160档={f['rows_lo']:3d} 128档={f['rows_mid']:3d} "
          f"100档={f['rows_hi']:3d} | >60%: {f['rowslo_60']:3d} {f['rowsmid_60']:3d} {f['rowshi_60']:3d} | 墨={f['ink']}")
