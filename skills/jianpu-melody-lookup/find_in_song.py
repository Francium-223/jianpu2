# -*- coding: utf-8 -*-
"""在**某一份谱内部**找与查询最接近的窗口, 并报出它落在第几小节。
用法: py -3.13 find_in_song.py 神々 33565653253
"""
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

pat = sys.argv[1] if len(sys.argv) > 1 else "神々"
Q = [str(d) for d, _a, _o in jptok.query(sys.argv[2] if len(sys.argv) > 2 else "33565653253")]
n = len(Q)

rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
for r in [x for x in rows if pat in (x.get("title") or "")]:
    notes = jptok.seq(r.get("score") or "")
    digs = [str(d) for d, _a, _o in notes]
    bars = sorted(set(int(x) for x in (r.get("bars") or [])))
    def bar_of(i):
        k = 0
        for j, b in enumerate(bars):
            if i < b:
                return j + 1
            k = j
        return len(bars) + 1
    print(f"=== {r['file'][0]}  {r.get('title')}  {len(notes)} 音  {len(bars)} 小节")
    best = []
    for i in range(len(digs) - n + 1):
        e = sum(1 for j in range(n) if digs[i + j] != Q[j])
        best.append((e, i))
    best.sort()
    for e, i in best[:5]:
        b0, b1 = bar_of(i), bar_of(i + n - 1)
        print(f"  起始音 {i:>3} (第 {b0} 小节)  差 {e} 音   库内: {' '.join(digs[i:i + n])}")
        print(f"      你的输入: {' '.join(Q)}")
