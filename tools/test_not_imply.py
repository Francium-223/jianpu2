# -*- coding: utf-8 -*-
"""针对性验证: where_not_imply 合并两个循环后, 语义是否与原来一致。

当前 309 份曲谱里没有一个用 `!tag`, 所以全量跑证明不了 —— 这里造合成用例,
把"原来的两循环版本"和"合并后的版本"跑同一批输入, 逐个对比结果。
"""
import io
import os
import re
import sys
import types

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu-db")

# 把新 score.py 复制成 _old_score.py, 并把 where_not_imply 换回旧版
src = io.open("score.py", encoding="utf-8").read()
m = re.search(r"\tdef where_not_imply\(self, n, p\):.*?\n(?=\tdef )", src, re.S)
assert m, "找不到 where_not_imply"
OLD = '''\tdef where_not_imply(self, n, p):
\t\to = ''
\t\tif '/' in n:
\t\t\to = n.split('/')
\t\t\tn = o[0]
\t\tfor k, v in goto_node(p).items():
\t\t\tif k == n and set(self.orignottag) & set(p):
\t\t\t\tself.nottag = safe_add(self.nottag, p)
\t\t\tself.where_not_imply(n, p + [k])
\t\tfor k, v in goto_node(p).items():
\t\t\tif k == n:
\t\t\t\tfor l in self.orignottag:
\t\t\t\t\tif ('/').join(p + [k]).endswith(l):
\t\t\t\t\t\tself.nottag_route = maybe_add(self.nottag_route, ('/').join(p + [k]))
\t\t\tif o:
\t\t\t\tself.where_not_imply(('/').join(o[1:]), p + [k])
\t\t\telse:
\t\t\t\tself.where_not_imply(n, p + [k])
'''
io.open("_old_score.py", "w", encoding="utf-8").write(src[:m.start()] + OLD + src[m.end():])

_stub = types.ModuleType("schema")
_stub.schema = {}
sys.modules["schema"] = _stub
sys.path.insert(0, r"D:\Documents_D\jianpu-db")
import score as NEW
import importlib.util
spec = importlib.util.spec_from_file_location("_old_score", "_old_score.py")
OLD_MOD = importlib.util.module_from_spec(spec)
spec.loader.exec_module(OLD_MOD)

BASE = io.open("scores/th10_06.txt", encoding="utf-8").read()
CASES = [
    ("单段 !tag", "!th01"),
    ("单段 !tag(自己)", "!th10"),
    ("单段 !tag(根)", "!东方"),
    ("路径 !tag", "!东方/东方原曲/ZUN/th10"),
    ("路径 !tag(另一个分支)", "!东方/东方原曲/ZUN/东方旧作原曲/th01"),
    ("正常 tag(对照)", "th10"),
]
print(f"{'用例':26s} {'新旧一致':8s} tag/nottag 摘要")
print("-" * 78)
ok = True
for label, ut in CASES:
    row = []
    for mod, tag in ((NEW, "new"), (OLD_MOD, "old")):
        txt = BASE.replace("usertag=th10", f"usertag=th10,{ut}")
        p = f"_t_{tag}.txt"
        io.open(p, "w", encoding="utf-8").write(txt)
        sc = mod.Score(p)
        sc.read()
        sc.process_others()
        row.append((sorted(sc.others.get("tag", [])), sorted(getattr(sc, "tag_route", []))))
        os.remove(p)
    same = row[0] == row[1]
    ok = ok and same
    print(f"{label:26s} {'✓' if same else '✗ 不一致':8s} tag={row[0][0][:4]}… route={row[0][1][:2]}")
os.remove("_old_score.py")
for f in os.listdir("."):
    if f.startswith("__pycache__"):
        pass
print()
print("结论:", "新旧语义完全一致 ✓" if ok else "存在差异 ✗")
