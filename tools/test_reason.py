# -*- coding: utf-8 -*-
"""测 THERE IS A REASON: 假 '-' 是否消失。"""
import os, sys, glob
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

imgs = glob.glob("images-prep/**/*THERE*REASON*/001.jpg", recursive=True)
print("找到图:", len(imgs))
for im in imgs[:1]:
    print("  ", im)
    toks, meta = JP.render(im, "train-work/test_reason.png")
    dash = sum(1 for t in toks if t == "-")
    print(f"音{len(toks)}  其中 '-' 有 {dash} 个 ({100*dash/max(len(toks),1):.0f}%)")
    print("序列:", " ".join(toks[:80]))
