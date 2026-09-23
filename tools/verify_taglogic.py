# -*- coding: utf-8 -*-
"""验证 taglogic 从 tags.json 派生的结果 == 旧的 tag_implications.json / tag_equality.json。

等值则说明"重写"没有改变任何行为 —— 只是把冗余数据换成派生。
"""
import json
import os
import sys

sys.path.insert(0, r"D:\Documents_D\jianpu2\tools")   # taglogic 副本(你的仓库里已删)
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu-db")

import taglogic as TL


def deep_eq(a, b, path=""):
    """递归比较, 并把差异收集成列表(含键顺序)。"""
    diffs = []
    if isinstance(a, dict) and isinstance(b, dict):
        ka, kb = list(a.keys()), list(b.keys())
        if ka != kb:
            diffs.append(f"{path}: 键不同/顺序不同\n    新: {ka}\n    旧: {kb}")
        for k in ka:
            if k in b:
                diffs += deep_eq(a[k], b[k], f"{path}/{k}")
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            diffs.append(f"{path}: 长度不同 新{len(a)} 旧{len(b)}")
        for i in range(min(len(a), len(b))):
            diffs += deep_eq(a[i], b[i], f"{path}[{i}]")
    else:
        if a != b:
            diffs.append(f"{path}: 新={a!r} 旧={b!r}")
    return diffs


TAGS = r"D:\Documents_D\jianpu-db\tags.json"   # 副本从你的仓库读真源
t = TL.get(TAGS)
print(f"tags.json 解析: 节点 {len(t._order)} 个, 别名组 {len(t.equal[0])} 组\n")

old_imply = json.load(open("tag_implications.json", encoding="utf-8"))
old_equal = json.load(open("tag_equality.json", encoding="utf-8"))

d1 = deep_eq(t.imply, old_imply)
d2 = deep_eq(t.equal, old_equal)

print("蕴涵 imply  vs  tag_implications.json :", "✅ 完全等值" if not d1 else f"❌ {len(d1)} 处差异")
for x in d1[:6]:
    print("   ", x)
print("等同 equal  vs  tag_equality.json    :", "✅ 完全等值" if not d2 else f"❌ {len(d2)} 处差异")
for x in d2[:6]:
    print("   ", x)

# 额外抽查: 用真实曲谱的 tag/tagroute 反推, 看派生是否正确
print("\n抽查验证(用真实曲谱):")
import glob
import io
bad = 0
checked = 0
for f in sorted(glob.glob("scores/th1*.txt"))[:200]:
    txt = io.open(f, encoding="utf-8", errors="replace").read()
    tag = route = ""
    for line in txt.splitlines():
        # 注意 "tagroute=" 是 9 个字符 —— 之前写 line[8:] 会多留下一个 '=' 前缀
        if line.startswith("tag="):
            tag = line.split("=", 1)[1].strip()
        elif line.startswith("tagroute="):
            route = line.split("=", 1)[1].strip()
        if tag and route:
            break
    if not tag or not route:
        continue
    checked += 1
    leaf = route.split("/")[-1]                    # 最末一段 = 该曲的 usertag
    want_route = t.route_of(leaf)
    want_anc = set(t.alias_closure([leaf]))
    got_tag = set(x.strip() for x in tag.split(",") if x.strip())
    if want_route != route:
        bad += 1
        if bad <= 3:
            print(f"   ✗ {os.path.basename(f)}: 路径不符\n      推 {want_route}\n      实际 {route}")
    missing = want_anc - got_tag
    if missing:
        bad += 1
        if bad <= 5:
            print(f"   ✗ {os.path.basename(f)}: tag 缺 {sorted(missing)[:5]}")

print(f"   检查 {checked} 份, 不一致 {bad} 份")
