# -*- coding: utf-8 -*-
"""检查 source= 兜底: 无 `__站点-id` 的名字也要写出来源。"""
import os
import sys

sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import to_jianpu_db as T

toks = ["1", "2", "3", "4", "5", "6", "7", "1", "2", "3", "4", "5"]
for n in ["不潮不用花钱", "英雄_21qupu", "英雄_qpcxw", "相思遥", "浮夸__jianpucn-133666"]:
    s = T.to_score(n, toks, "t")
    src = [l for l in s.splitlines() if l.startswith("source=")]
    print(f"{n:<26} {src[0] if src else '(无 source=!)'}")
