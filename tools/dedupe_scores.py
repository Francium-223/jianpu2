# -*- coding: utf-8 -*-
"""清掉 jianpu-db-out/scores 里**同一来源重复**的文件。

为什么会有重复: 文件名只在"标题撞名"时加 _2/_3 后缀, 而哪个文件先处理决定了谁拿到后缀;
换一次运行顺序, 同一份源谱就可能同时留下 `X.txt` 和 `X_2.txt`(source= 一模一样)。
直接跑 to_jianpu_db 不像 finalize 那样先清空目录, 所以会攒下这些。

判据: 只在 **source= 完全相同** 时才删(绝不误删"同名但不同源"的谱)。
保留: 名字里没有 `_N` 后缀的那份; 若都有后缀则保留字典序最小的。
用法: py -3.13 tools/dedupe_scores.py [--apply]      （默认只报告不删）
"""
import os
import re
import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

APPLY = "--apply" in sys.argv
DIR = "jianpu-db-out/scores"

groups = defaultdict(list)
for fn in os.listdir(DIR):
    if not fn.endswith(".txt"):
        continue
    p = os.path.join(DIR, fn)
    try:
        head = open(p, encoding="utf-8", errors="replace").read(1200)
    except Exception:
        continue
    m = re.search(r"^source=(.+)$", head, re.M)
    if not m:
        continue
    groups[m.group(1).strip()].append(fn)

dups = {k: v for k, v in groups.items() if len(v) > 1}
print(f"scores {len(os.listdir(DIR))} 份; 同一来源多份的: {len(dups)} 组, "
      f"多出的文件 {sum(len(v) - 1 for v in dups.values())} 个")

doomed = []
for src, fns in sorted(dups.items()):
    fns_sorted = sorted(fns, key=lambda x: (bool(re.search(r"_\d+\.txt$", x)), x))
    keep, rest = fns_sorted[0], fns_sorted[1:]
    doomed += [(f, src, keep) for f in rest]
    if len(doomed) <= 8:
        print(f"  保留 {keep}   删 {'、'.join(rest)}   [{src[:60]}]")

if APPLY:
    n = 0
    for f, src, keep in doomed:
        try:
            os.remove(os.path.join(DIR, f))
            n += 1
        except Exception as e:
            print(f"  删除失败 {f}: {e}")
    print(f"已删除 {n} 个重复文件")
else:
    print("（只报告，未删除；加 --apply 才真删）")
