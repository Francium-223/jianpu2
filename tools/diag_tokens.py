# -*- coding: utf-8 -*-
"""诊断: 打印上春山前若干 token 的块信息(位置/类型/beam)。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
from geo_detect import geo_detect
from PIL import Image
import numpy as np

im = glob.glob("images-prep/hot-crawl/上春山__qinyipu-377784/*")[0]
toks, meta = JP.render(im, "train-work/tmp_diag.png")
print(f"总 token {len(toks)}\n")
print(f"{'i':>3} {'tok':>7} {'band':>5} {'x0':>5} {'x1':>5} {'ny0':>5} {'y1':>5}  type")
for i, (t, m) in enumerate(zip(toks[:30], meta[:30])):
    print(f"{i:3d} {t:>7} {m['band']:5d} {m['x0']:5d} {m['x1']:5d} {m['ny0']:5d} {m['y1']:5d}  {m['btype']}")
