# -*- coding: utf-8 -*-
"""列出转写里所有带附点的 token 及其在图上的位置。用法: py tools/dot_where.py <图>"""
import os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP

img = sys.argv[1]
toks, meta = JP.transcribe(img)
print(f"{os.path.basename(img)}: {len(toks)} token")
n = 0
for t, m in zip(toks, meta):
    if "." in t:
        n += 1
        print(f"  附点token {t!r}  行带y={m['s']} 块x=[{m['x0']},{m['x1']}] ny=[{m['ny0']},{m['y1']}]")
print(f"共 {n} 个附点")
