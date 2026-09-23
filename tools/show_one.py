# -*- coding: utf-8 -*-
"""渲染 两只老虎 的标注框图 + 输出转写序列。用法: py tools/show_one.py <id>"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

kid = sys.argv[1] if len(sys.argv) > 1 else "jianpujia-15847"
out = sys.argv[2] if len(sys.argv) > 2 else f"train-work/show_{kid}.png"
hits = [p for p in glob.glob("images-prep/*/*") if os.path.basename(p).endswith(kid)]
if not hits:
    print("找不到", kid); sys.exit(1)
page = BT.pick_page(hits[0])
toks, meta = BT.transcribe_paged(page, f"train-work/show_{kid}.txt", out)
s = " ".join(toks)
d = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
dot = sum(1 for t in toks if "." in t)
x = sum(1 for t in toks if "x" in t)
print(f"{os.path.basename(hits[0])[:40]}")
print(f"页={os.path.basename(page)}  框图={out}")
print(f"token {len(toks)}  数字{d}  附点{dot}  x{x}")
print()
print(s)
