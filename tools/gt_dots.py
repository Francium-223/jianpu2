# -*- coding: utf-8 -*-
"""spring GT 的附点数量。"""
import re, sys
sys.stdout.reconfigure(encoding="utf-8")
gts = [l.strip() for l in open("train-work/gt/春天在哪里.txt", encoding="utf-8").read().splitlines()]
gtl = [l for l in gts if re.match(r"^[qsdh,']*[0-9x,\-()'qsdh ]", l)]
gs = " ".join(gtl).replace("(", " ").replace(")", " ")
GT = [x for x in gs.split() if re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0-][.,'qsdh#b-]*$", x) or x == "-"]
dd = [t for t in GT if "." in t]
print(f"GT 共 {len(GT)} 音符, 附点 {len(dd)} 个")
print("附点token:", dd)
