# -*- coding: utf-8 -*-
"""测 x(念白记号) 识别: 跑 TogetherWeFight(有 X 符号) 看能否转出 x。"""
import os, sys, glob, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

imgs = glob.glob("images-prep/**/*TogetherWeFight*/001.jpg", recursive=True)
print("找到图:", len(imgs))
if imgs:
    t0 = time.time()
    toks, meta = JP.render(imgs[0], "train-work/test_x.png")
    dt = time.time() - t0
    nx = sum(1 for t in toks if "x" in t)
    print(f"音{len(toks)}  含x的token {nx} 个  耗时{dt:.0f}s")
    print("序列:", " ".join(toks[:100]))
