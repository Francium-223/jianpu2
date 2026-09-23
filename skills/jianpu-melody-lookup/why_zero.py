# -*- coding: utf-8 -*-
"""查: 搜 623532 为什么代价 0? 把命中的那份谱的那一段原样摊开。"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402
import gate   # noqa: E402

gate.gate(os.path.join(HERE, "data.jsonl"))

Q = jptok.query(sys.argv[1] if len(sys.argv) > 1 else "623532")
qd = [d for d, _a, _o in Q]
print(f"查询 {jptok.show(Q)}  ({len(Q)} 音)")

# 复刻 Python 侧的匹配: 用 jptok 解析每份谱, 报代价 0 的**全部**位置
rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
n = len(qd)
hits = []
for r in rows:
    note = jptok.seq(r.get("score") or "")
    dig = [d for d, _a, _o in note]
    for i in range(len(dig) - n + 1):
        if dig[i:i + n] == qd:
            hits.append((r.get("title"), r.get("source"), i, note[i:i + n]))
            break
print(f"代价 0 的曲目: {len(hits)} 首")
for t, s, i, seg in hits[:12]:
    print(f"  {str(t)[:24]:<26} {s}  位置 {i}")
    print(f"     库内该段: {jptok.show(seg)}")
