# -*- coding: utf-8 -*-
"""重构后的两个行为测试(不写仓库: 只 Score.read(), 不 parse())。

A) 乱序注入: 把 schema 的**声明顺序**打乱 -> 每份谱的 tag/tagroute 必须与 golden 相同
   (这证明"顺序由 deps 决定, 而不是由书写顺序决定")
B) 环注入: 让 tag <-> tagroute 互相依赖 -> order() 必须 Warning 且不崩; strict=True 抛错
"""
import io
import json
import os
import random
import sys
import warnings

REPO = r"D:\Documents_D\jianpu-db"
os.chdir(REPO)
sys.path.insert(0, REPO)
sys.stdout.reconfigure(encoding="utf-8")
import schema
import score as SC

golden = json.load(io.open("data.json", encoding="utf-8"))
files = sorted(golden.keys())
print(f"golden 谱 {len(files)} 份")

# ---------- A) 乱序注入 ----------
items = list(schema.schema.items())
random.seed(0)
random.shuffle(items)
schema.schema = dict(items)
print("\nA) 打乱后的声明顺序:", list(schema.schema))
print("   order() =", schema.order(), "  (依赖决定, 与上面顺序无关)")
print("   仍与 golden 逐项一致? ", end="")
bad = []
for fn in files:
    sc = SC.Score("scores/" + fn)
    try:
        sc.read()
    except Exception as e:
        bad.append((fn, f"read 异常 {type(e).__name__}"))
        continue
    g = golden[fn]
    if sc.others.get("tag") != g.get("tag"):
        bad.append((fn, "tag 不同"))
    elif sc.others.get("tagroute") != g.get("tagroute"):
        bad.append((fn, "tagroute 不同"))
print("是 ✓" if not bad else f"**否 ✗ {len(bad)} 份** 例: {bad[:3]}")

# ---------- B) 环注入 ----------
print("\nB) 环注入: tag <-> tagroute 互相依赖")
schema.schema["tag"] = schema.Attr(schema.derive_tag, ("usertag", "tagroute"))
schema.schema["tagroute"] = schema.Attr(schema.derive_tagroute, ("usertag", "tag"))
with warnings.catch_warnings(record=True) as w:
    warnings.simplefilter("always")
    o = schema.order()
    print("   普通调用: 返回顺序 =", o)
    print("   警告数 =", len(w), "->", str(w[0].message)[:100] if w else "(无)")
try:
    schema.order(strict=True)
    print("   strict=True: **没有抛错 ✗**")
except RuntimeError as e:
    print("   strict=True: 抛 RuntimeError ✓ ->", str(e)[:90])
