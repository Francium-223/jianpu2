# -*- coding: utf-8 -*-
"""验证 title_of 的三级修法: 正常/可逆mojibake/不可逆mojibake 各取几个。"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from to_jianpu_db import title_of

CASES = [
    ("问候歌简谱_儿歌演唱-简谱__jianpujia-1", "正常中文"),
    ("10信念（双谱）__qupu123-319833", "带序号"),
    ("ä¸­å_½å°_å¹´å__qupu123-1", "不可逆(部分可救)"),
    ("ä¸_è_²å__qupu123-2", "不可逆(救不回)"),
    ("å_2__jianpucn-12345", "不可逆(单字)"),
    ("TogetherWeFight_æ­£ä¹_çº¢å__jianpucn-9", "英文+部分可救"),
]
for n, kind in CASES:
    print(f"  [{kind:16s}] {n[:38]:40s} -> {title_of(n)}")
