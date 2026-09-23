# -*- coding: utf-8 -*-
"""检查交付物标题是否干净: 不该带源站后缀、源 ID、mojibake、控制字符。"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

fs = glob.glob("jianpu-db-out/scores/*.txt")
bad_suffix = bad_id = bad_moji = bad_ctrl = 0
ex = {"suffix": [], "id": [], "moji": [], "ctrl": []}
for f in fs:
    b = os.path.basename(f)[:-4]
    if re.search(r"(jianpu\.cn|qupu123|jianpujia|jianpucn|__)", b):
        bad_suffix += 1
        if len(ex["suffix"]) < 5:
            ex["suffix"].append(b)
    if re.search(r"(qupu123|jianpujia|jianpucn)-\d+$", b):
        bad_id += 1
        if len(ex["id"]) < 5:
            ex["id"].append(b)
    if re.search(r"[\u00c0-\u00ff]{2,}", b):
        bad_moji += 1
        if len(ex["moji"]) < 5:
            ex["moji"].append(b)
    if any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in b):
        bad_ctrl += 1
        if len(ex["ctrl"]) < 5:
            ex["ctrl"].append(repr(b))

print(f"scores {len(fs)} 个标题检查:")
print(f"  含源站/__ 后缀: {bad_suffix}")
for x in ex["suffix"]:
    print(f"      {x[:60]}")
print(f"  含源 ID 后缀: {bad_id}")
for x in ex["id"]:
    print(f"      {x[:60]}")
print(f"  含 mojibake: {bad_moji}")
for x in ex["moji"]:
    print(f"      {x[:60]}")
print(f"  含控制字符: {bad_ctrl}")
for x in ex["ctrl"]:
    print(f"      {x[:60]}")
print("\n样例(前 8 个标题):")
for f in sorted(fs)[:8]:
    print("   " + os.path.basename(f)[:-4][:56])
