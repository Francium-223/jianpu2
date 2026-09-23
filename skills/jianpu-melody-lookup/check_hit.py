# -*- coding: utf-8 -*-
"""统一口径后复验: 库内某首歌在指定查询下的命中位置 + 原谱片段(含升降号)。

用法: py -3.13 check_hit.py <曲名子串> <查询串>
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402

pat = sys.argv[1] if len(sys.argv) > 1 else "U.N"
Q = jptok.query(sys.argv[2] if len(sys.argv) > 2 else "63731232")
qd = [d for d, _a, _o in Q]
print(f"查询 {jptok.show(Q)}  ({len(Q)} 音)")

rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
hits = [r for r in rows if pat in (r.get("title") or "")]
print(f"标题含 {pat!r}: {len(hits)} 份\n")

for r in hits:
    note = jptok.seq(r.get("score") or "")
    dig = [d for d, _a, _o in note]
    print(f"=== {r['file'][0]}  {r.get('title')}  n_notes={r.get('n_notes')}  解析出 {len(note)} 音")
    # 精确子串(音级序列)
    n = len(qd)
    pos = -1
    for i in range(len(dig) - n + 1):
        if dig[i:i + n] == qd:
            pos = i
            break
    if pos < 0:
        # 最接近
        best = None
        for i in range(max(0, len(dig) - n + 1)):
            e = sum(1 for j in range(n) if dig[i + j] != qd[j])
            if best is None or e < best[0]:
                best = (e, i)
        if best:
            pos, e = best[1], best[0]
            print(f"   **不含**; 最接近在音 {pos}, 差 {e} 音")
        else:
            print("   谱太短"); continue
    else:
        print(f"   命中(音级序列)于音 {pos}")
    a, b = max(0, pos - 5), min(len(note), pos + n + 5)
    seg = " ".join(("*" if pos <= i < pos + n else " ") + jptok.show([note[i]])
                   for i in range(a, b))
    print(f"   原谱片段: {seg}")
    print(f"   命中段带记号: {jptok.show(note[pos:pos + n])}")
    print(f"   你的输入    : {jptok.show(Q)}")
    print()
