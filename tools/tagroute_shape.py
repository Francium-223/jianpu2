# -*- coding: utf-8 -*-
"""量 tagroute 的真实形态: 有多少份是多路径、多少份存在"一条是另一条前缀"(maybe_add 该折叠的情形)。"""
import glob
import io
import os
import re
import sys
from collections import Counter

os.chdir(r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")

rows = []
for f in glob.glob("scores/*.txt"):
    t = io.open(f, encoding="utf-8", errors="replace").read()
    m = re.search(r"(?m)^tagroute=(.*)$", t)
    routes = [x.strip() for x in (m.group(1).split(',') if m else []) if x.strip()]
    m2 = re.search(r"(?m)^usertag=(.*)$", t)
    rows.append((os.path.basename(f), (m2.group(1).strip() if m2 else ""), routes))

print(f"谱 {len(rows)} 份")
c = Counter(len(r[2]) for r in rows)
print("  每条谱的 tagroute 条数分布:", dict(sorted(c.items())))
pref = []
for name, u, routes in rows:
    hit = [(a, b) for a in routes for b in routes if a != b and b.startswith(a + "/")]
    if hit:
        pref.append((name, u, hit))
print(f"\n  存在'一条是另一条前缀'的谱: {len(pref)} 份")
for n, u, hit in pref[:6]:
    print(f"     {n[:34]:<36} usertag={u[:18]:<20} {hit[:1]}")

multi = [r for r in rows if len(r[2]) > 1]
print(f"\n  多路径(>1)的谱: {len(multi)} 份, 例:")
for n, u, routes in multi[:6]:
    print(f"     {n[:30]:<32} usertag={u[:14]:<16}")
    for x in routes[:3]:
        print(f"        {x[:100]}")

# tag 字段里"段"和"整名"混装的证据
m = re.search(r"(?m)^tag=(.*)$", io.open(rows[0][0] if rows else "", encoding="utf-8").read()) if rows else None
print("\n  tag 字段是把路径**拆成段**后混装的(例):")
if rows:
    t = io.open("scores/" + rows[0][0], encoding="utf-8").read()
    mt = re.search(r"(?m)^tag=(.*)$", t)
    mr = re.search(r"(?m)^tagroute=(.*)$", t)
    print(f"     tag      = {mt.group(1)[:120] if mt else ''}")
    print(f"     tagroute = {mr.group(1)[:120] if mr else ''}")
