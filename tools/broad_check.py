# -*- coding: utf-8 -*-
"""广泛验证: 渲染若干风格不同的谱, 供人眼检查残留问题(怪框/漏框/标签错)。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import glob
import batch_transcribe as BT
import jp_transcribe as JP

SHEETS = ["qupu123-312866", "jianpujia-15847", "jianpujia-15680", "qupu123-331946"]
for kid in SHEETS:
    hits = [p for p in glob.glob("images-prep/*/*") if os.path.basename(p).endswith(kid)]
    if not hits:
        print(kid, "缺"); continue
    page = BT.pick_page(hits[0])
    out = f"train-work/chk_{kid}.png"
    toks, meta = BT.transcribe_paged(page, f"train-work/chk_{kid}.txt", out)
    s = " ".join(toks)
    d = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    print(f"{kid}: 页={os.path.basename(page)} 音{len(toks)} 数字{d} -> {out}")
    print(f"    {s[:150]}")
