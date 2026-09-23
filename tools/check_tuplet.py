# -*- coding: utf-8 -*-
"""查证: 我的转写是否把三连音标记的 3 读成了音符。
对比 兄弟抱一下 的 GT(含 3[ 标记) 与我的转写在该位置的 token。
"""
import io, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from token_json import is_tuplet_marker, is_marker

gt = io.open("train-work/gt/兄弟抱一下.txt", encoding="utf-8").read().split()
out = io.open("train-work/gt_eval/兄弟抱一下.txt", encoding="utf-8").read().split()

print("GT 里的结构符号:")
for i, t in enumerate(gt):
    if is_tuplet_marker(t) or is_marker(t):
        ctx = " ".join(gt[max(0, i - 3):i + 4])
        print(f"   位置{i:4d}  {t!r:8s}  …{ctx}…")
        if i > 120:
            break

print("\nGT 里 3[ 之后紧跟的音符(应该是三连音的三个音):")
for i, t in enumerate(gt):
    if is_tuplet_marker(t):
        print(f"   {t} -> {' '.join(gt[i+1:i+5])}")
        break

print("\n我的转写开头 30 个:", " ".join(out[:30]))
print("\nGT 开头 30 个:", " ".join(gt[:30]))
