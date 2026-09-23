# -*- coding: utf-8 -*-
"""架构检查: 量化 where_not_imply 的递归量 + 验证 homonym 字典被覆盖的 bug。"""
import sys
import types

sys.path.insert(0, r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")
import os
os.chdir(r"D:\Documents_D\jianpu-db")
_stub = types.ModuleType("schema")
_stub.schema = {}
sys.modules["schema"] = _stub
import score as S

# --- 1) 统计 where_not_imply / where_imply 的调用次数(树只有 42 个节点) ---
cnt = {"not": 0, "im": 0}
_orig_not = S.Score.where_not_imply
_orig_im = S.Score.where_imply


def patched_not(self, n, p):
    cnt["not"] += 1
    return _orig_not(self, n, p)


def patched_im(self, n, p):
    cnt["im"] += 1
    return _orig_im(self, n, p)


S.Score.where_not_imply = patched_not
S.Score.where_imply = patched_im

sc = S.Score("scores/th10_06.txt")
sc.read()
sc.process_others()
print(f"单个 !tag 的 where_not_imply 调用次数: {cnt['not']}")
print(f"tag 的 where_imply 调用次数:            {cnt['im']}")
print(f"(整棵树只有 {len(S.imply)} 个顶层节点 / 42 个节点)")

# --- 2) homonym 字典覆盖 bug ---
print()
print("find_tag 里的 homonym 收集(score.py L212-221):")
import inspect
src = inspect.getsource(S.Score.find_tag)
for line in src.splitlines():
    if "maybe_homonym" in line:
        print("   " + line.strip())
