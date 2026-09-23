# -*- coding: utf-8 -*-
"""把 token 映射回图上的位置: 看开头那些 token 到底来自哪儿。"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT
import jp_transcribe as JP

img = r"images-prep/qupu123-crawl/友谊天长地久（日语版）__qupu123-369903/003.jpg"
pages = BT.split_pages(img)
page = pages[0]
toks, meta = JP.transcribe(page)
print(f"页 {os.path.basename(page)}  token {len(toks)}\n")
print("序号  行带y      块bbox(x0,x1,ny0,y1)   类型   token")
for i, (t, m) in enumerate(zip(toks, meta)):
    print(f"{i+1:4d}  y={m['s']:4d}-{m['e']:<4d} x=[{m['x0']:4d},{m['x1']:4d}] "
          f"ny=[{m['ny0']:3d},{m['y1']:3d}] {m['btype']:6s} {t}")
