# -*- coding: utf-8 -*-
"""jianpu-db/data.jsonl 的真实字段 vs README 里讲到的字段（只读，别猜）。

用法: py -3.13 check_data_fields_doc.py
输出: 三行 —— 数据字段、README 讲的字段、两边的差集。
"""
import collections
import io
import json
import os
import re
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.join(os.path.dirname(ROOT), "jianpu-db")
DATA = os.path.join(REPO, "data.jsonl")
README = os.path.join(REPO, "README.md")

keys = collections.Counter()
n = 0
for line in io.open(DATA, encoding="utf-8"):
    if not line.strip():
        continue
    n += 1
    for k in json.loads(line):
        keys[k] += 1

txt = io.open(README, encoding="utf-8").read()
doc = set(re.findall(r"^\|\s*`([A-Za-z_][A-Za-z0-9_]*)`", txt, flags=re.M))
doc |= set(re.findall(r"^\|\s*([A-Za-z_][A-Za-z0-9_]*)=", txt, flags=re.M))
doc |= set(re.findall(r"^\|\s*([A-Za-z_][A-Za-z0-9_]*)\s*\|", txt, flags=re.M))

print("data.jsonl %d 行，字段 %d 个:" % (n, len(keys)))
for k, c in keys.most_common():
    print("    %-14s %6d 行 (%5.1f%%)" % (k, c, c * 100.0 / n))
print()
print("README 表格里讲到的名字 %d 个: %s" % (len(doc), " ".join(sorted(doc))))
print()
only_data = sorted(set(keys) - doc)
only_doc = sorted(doc - set(keys))
print("★ 数据里有、README 表格没讲: %s" % (only_data or "（无）"))
print("★ README 讲了、数据里没有: %s" % (only_doc or "（无）"))
if only_doc:
    print("  （这几个不是 data.jsonl 字段 —— 它们是**曲谱文件头**的指令，"
          "在 README「规范/曲谱文件」那节讲；两边混在一起看会以为缺字段）")
