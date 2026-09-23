# -*- coding: utf-8 -*-
"""对比重构前后的交付物哈希(黄金测试)。"""
import hashlib
import os
import sys

os.chdir(r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")
BASE = {"data.json": "d0bb7403b30a97a1", "data.jsonl": "a21e9d33a5187129"}
ok = True
for f, b in BASE.items():
    h = hashlib.sha256(open(f, "rb").read()).hexdigest()[:16]
    same = (h == b)
    ok = ok and same
    print(f"  {f}: {h}   baseline {b}   " + ("逐字节相同 ✓" if same else "**不同 ✗**"))
print()
print("  结论: " + ("重构后输出与重构前逐字节一致 ✓" if ok else "有语义漂移 ✗"))
