# -*- coding: utf-8 -*-
"""验证 c(四分音符, jianpu-ly KeepLength 写法) 被正确解析。"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from token_json import token_to_json, normalize_tokens

for x in ["6c.", "3c", "c6", "q3", "5s"]:
    j = token_to_json(x)
    print(f"  {x:5s} -> digit={j['digit']!r:5s} beam={j['beam']} dotted={j['dotted']}")

print("\n规范化(不带 c 的旧行为会把 6c. 丢掉):")
seq = "3 3 5 6c. 5s 6 5q 3 2 5 3c".split()
print("  输入:", " ".join(seq))
print("  输出:", " ".join(normalize_tokens(seq, merge_ties=True)))
