# -*- coding: utf-8 -*-
"""清掉 batch-out 里名字含控制字符的旧 txt/png(已被 safe_name 规范化版本取代)。"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
CTRL = re.compile(r"[\x00-\x1f\x7f-\x9f]")
n = 0
for f in glob.glob("batch-out/*.txt") + glob.glob("batch-out/*.png"):
    b = os.path.basename(f)
    if b in ("progress.txt", "skipped.txt"):
        continue
    if CTRL.search(b):
        os.remove(f)
        n += 1
print(f"删除旧名(含控制字符)文件: {n}")
fs = [f for f in glob.glob("batch-out/*.txt") if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
print(f"剩余 txt: {len(fs)}")
print(f"仍含控制字符: {sum(1 for f in fs if CTRL.search(os.path.basename(f)))}")
