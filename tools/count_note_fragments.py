# -*- coding: utf-8 -*-
"""统计 data.jsonl 的 `score` 里"有符号但没音高"的碎片(以及调号漏进正文)。

背景: 21 首的 `score` 里出现 `c~`/`q~`/`1=C` 这类 jptok 解析不了的 token。
`c~` = 时值字母 + 连音线, **没有音高** —— 放在一串音高之间(如 `c'1 c- c- c- c~ q'1`)
很可能是**那里丢了一个音高的音**。自检门那条"数字数==旋律数"抓不到它(碎片里没数字)。
只读。
"""
import collections
import io
import json
import os
import re
import sys

DB = r"D:\Documents_D\jianpu-db"
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402

FRAG = re.compile(r"^[cqsdh]+[~\[\]]*$")          # 时值 + 连音线/括号, 没有数字
KEY = re.compile(r"^\d+=[A-Ga-g]")                # 调号行漏进正文

frag = collections.Counter()
per_file = collections.Counter()
key_leak = []
for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
    if not l.strip():
        continue
    r = json.loads(l)
    f = r["file"][0]
    for t in (r.get("score") or "").split():
        if t == "|" or jptok.is_note(t):
            continue
        if FRAG.match(t):
            frag[t] += 1
            per_file[f] += 1
        elif KEY.match(t):
            frag[t] += 1
            per_file[f] += 1
            if f not in key_leak:
                key_leak.append(f)

print("音符碎片(有符号没音高): %d 个, 分布在 %d 首" % (sum(frag.values()), len(per_file)))
print("最常见:", frag.most_common(8))
print("调号漏进正文的谱: %d %s" % (len(key_leak), key_leak[:6]))
print()
print("受影响最多的 10 首:")
for f, n in per_file.most_common(10):
    print("   %-30s %d 个" % (f, n))
