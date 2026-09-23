# -*- coding: utf-8 -*-
"""转写任意单张图。用法: py tools/transcribe_path.py <图片> <输出png前缀>"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

img = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "train-work/newsrc/out.png"
toks, meta = JP.render(img, out)
s = " ".join(toks)
d = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
dot = sum(1 for t in toks if "." in t)
x = sum(1 for t in toks if "x" in t)
q = sum(1 for t in toks if "?" in t)
print(f"token {len(toks)}  数字 {d}  附点 {dot}  x {x}  乱码 {q}")
print(f"框图: {out}")
print()
print(s)
