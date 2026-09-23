# -*- coding: utf-8 -*-
"""审计 jianpu-db 的 tag/tagroute 生成: 谁没有 tagroute、maybe_add 到底做了什么、tags.json 顶层。"""
import glob
import importlib.util
import io
import json
import os
import re
import sys
from collections import Counter

REPO = r"D:\Documents_D\jianpu-db"
os.chdir(REPO)
sys.path.insert(0, REPO)
sys.stdout.reconfigure(encoding="utf-8")

rows = []
for f in glob.glob("scores/*.txt"):
    t = io.open(f, encoding="utf-8", errors="replace").read()
    def get(k):
        m = re.search(r"(?m)^" + k + r"=(.*)$", t)
        return m.group(1).strip() if m else ""
    rows.append((os.path.basename(f), get("usertag"), get("tag"), get("tagroute")))

print(f"谱 {len(rows)} 份")
no_route = [r for r in rows if r[3] == ""]
print(f"**有 tag 没 tagroute: {len(no_route)} 份 ({len(no_route)/len(rows)*100:.1f}%)**")
print("  这些谱的 usertag 分布:")
for u, c in Counter(r[1] for r in no_route).most_common(20):
    print(f"     {c:>4}  usertag={u}")

with_route = [r for r in rows if r[3] != ""]
print("\n  对比: 有 tagroute 的 usertag 分布(前 8):")
for u, c in Counter(r[1] for r in with_route).most_common(8):
    print(f"     {c:>4}  usertag={u}")

# tag 里"叶子"和"路径段"是否混在一起
print("\n  例(有 route):")
for r in with_route[:2]:
    print(f"     {r[0]}: usertag={r[1]}")
    print(f"        tag      = {r[2][:110]}")
    print(f"        tagroute = {r[3][:110]}")

# maybe_add 语义实测
spec = importlib.util.spec_from_file_location("sc", os.path.join(REPO, "score.py"))
sc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sc)
print("\n maybe_add 实测:")
for a, b in (([], "a"), (["a"], "ab"), (["ab"], "a"), (["a", "ab"], "abc"),
             (["a", "abc"], "ab"), (["abc"], "abc"), (["a/b", "a/b/c"], "a/b/c/d")):
    print(f"     maybe_add({a!r:22} , {b!r:10}) = {sc.maybe_add(a, b)}")

# tags.json 顶层
tree = json.loads(io.open("tags.json", encoding="utf-8").read())
print(f"\n tags.json 顶层节点 {len(tree)} 个:")
print("   " + " | ".join((nd.get('name') or ['?'])[0] for nd in tree[:20]))
