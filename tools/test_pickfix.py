# -*- coding: utf-8 -*-
"""验证 pick_page 修复: 转写 4 首已知被挑错页的儿歌。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

for kid in ["jianpujia-15847", "jianpujia-15571", "jianpujia-15680", "jianpujia-15551"]:
    hits = [p for p in glob.glob("images-prep/*/*") if kid in os.path.basename(p)]
    if not hits:
        continue
    page = BT.pick_page(hits[0])
    toks, _ = BT.transcribe_paged(page, "train-work/_v.txt", "train-work/_v.png")
    s = " ".join(toks)
    d = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    dot = sum(1 for t in toks if "." in t)
    x = sum(1 for t in toks if "x" in t)
    print(f"{kid}  页={os.path.basename(page)}  音{len(toks)} 数字{d} 附点{dot} x{x}")
    print(f"    {s[:170]}")
