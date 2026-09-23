# -*- coding: utf-8 -*-
"""maybe_add 的行为实测(尤其是"顺序依赖"): 用真实 score.py, 不靠读代码下结论。"""
import importlib.util
import os
import sys

REPO = r"D:\Documents_D\jianpu-db"
os.chdir(REPO)
sys.path.insert(0, REPO)
sys.stdout.reconfigure(encoding="utf-8")
spec = importlib.util.spec_from_file_location("sc", os.path.join(REPO, "score.py"))
sc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sc)

cases = [
    (["a", "ab"], "a"),
    (["a", "ab", "abc"], "ab"),
    (["a/b", "a/b/c"], "a/b"),
    (["a/b/c"], "a/b"),
    (["a", "b"], "a"),
    (["ab", "abc"], "ab"),
    (["a"], "a"),
    (["a/b/c/d"], "a/b"),
]
print("maybe_add 实测:")
for a, b in cases:
    print(f"  maybe_add({a!r:26}, {b!r:10}) = {sc.maybe_add(a, b)}")
