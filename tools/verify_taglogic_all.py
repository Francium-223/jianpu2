# -*- coding: utf-8 -*-
"""全量验证 taglogic + 量化「东方同人曲」位置修正的影响面。"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, r"D:\Documents_D\jianpu2\tools")   # taglogic 副本(你的仓库里已删)
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu-db")
import taglogic as TL

TAGS = r"D:\Documents_D\jianpu-db\tags.json"   # 副本从你的仓库读真源
t = TL.get(TAGS)
files = [f for f in glob.glob("scores/*.txt")
         if not f.endswith(("_expand.txt", "_buf.txt"))]
print(f"全量检查 {len(files)} 份曲谱")

bad_route = bad_tag = 0
checked = 0
affect = []
for f in files:
    txt = io.open(f, encoding="utf-8", errors="replace").read()
    tag = route = ""
    for line in txt.splitlines():
        if line.startswith("tag="):
            tag = line.split("=", 1)[1].strip()
        elif line.startswith("tagroute="):
            route = line.split("=", 1)[1].strip()
        if tag and route:
            break
    if not tag or not route:
        continue
    checked += 1
    leaf = route.split("/")[-1]
    # 用**路径**算闭包(唯一正确做法): 同名节点可能出现在多处, 按名字查会歧义
    if t.route_of(leaf) != route and route not in t.routes_of(leaf):
        bad_route += 1
        if bad_route <= 3:
            print(f"  路径不符 {os.path.basename(f)}\n    推 {t.routes_of(leaf)}\n    实 {route}")
    want = set(t.closure_of_path(route.split("/")))
    got = set(x.strip() for x in tag.split(",") if x.strip())
    miss = want - got
    if miss:
        bad_tag += 1
        if bad_tag <= 3:
            print(f"  tag 缺项 {os.path.basename(f)}: {sorted(miss)}")
    # 影响面: 用了东方同人曲的谱
    if "东方同人曲" in got or "东方同人曲" in route:
        affect.append((os.path.basename(f), "东方原曲" in got))

print(f"\n检查 {checked} 份:  路径不符 {bad_route}, tag 缺项 {bad_tag}")
print(f"\n受「东方同人曲」改动影响的谱: {len(affect)} 份")
for nm, has_orig in affect[:10]:
    print(f"   {nm:28s} 旧数据里还被标为『东方原曲』: {has_orig}")
