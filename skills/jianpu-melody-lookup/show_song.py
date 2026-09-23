# -*- coding: utf-8 -*-
"""把一首曲谱按**小节**分段打出来(供人对着谱子/耳朵圈定是哪一段)。

用法: py -3.13 show_song.py 神々 [--bars-per-line 4] [--find 3356]

--find 会把某个音级串在**每个小节内**的位置标出来(用方括号夹住), 方便定位"我听到的那句"。
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402  **唯一口径**
import gate   # noqa: E402

gate.gate(os.path.join(HERE, "data.jsonl"))

pat = sys.argv[1] if len(sys.argv) > 1 else "神々"
PER = 4
if "--bars-per-line" in sys.argv:
    PER = int(sys.argv[sys.argv.index("--bars-per-line") + 1])
FIND = ""
if "--find" in sys.argv:
    FIND = "".join(str(x[0]) for x in jptok.query(sys.argv[sys.argv.index("--find") + 1]))

rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
hits = [r for r in rows if pat in (r.get("title") or "")]
print(f"标题含 {pat!r}: {len(hits)} 份" + (f"   找 {FIND}" if FIND else "") + "\n")

for r in hits:
    notes = jptok.seq(r.get("score") or "")
    bars = sorted(set(int(x) for x in (r.get("bars") or [])))
    print(f"=== {r['file'][0]}  {r.get('title')}  音符 {len(notes)}  小节 {len(bars)}  "
          f"{r.get('beats_per_bar')} 拍/小节  出处 {r.get('source')}")
    # 按小节切
    bounds = bars + [len(notes)]
    if bounds[0] != 0:
        bounds = [0] + bounds
    segs = []
    for i in range(len(bounds) - 1):
        a, b = bounds[i], bounds[i + 1]
        if b > a:
            segs.append((i + 1, a, b))
    line = []
    for idx, a, b in segs:
        digs = [str(d) for d, _acc, _o in notes[a:b]]
        # 标出 FIND 在本小节内的位置
        marks = set()
        if FIND:
            for k in range(len(digs) - len(FIND) + 1):
                if "".join(digs[k:k + len(FIND)]) == FIND:
                    marks.update(range(k, k + len(FIND)))
        parts = []
        for k, (d, acc, _o) in enumerate(notes[a:b]):
            s = ("#" if acc == 1 else "b" if acc == -1 else "") + str(d)
            if FIND and k in marks:
                s = "[" + s + "]"
            parts.append(s)
        line.append(f"[{idx}:{a}-{b - 1}] " + " ".join(parts))
        if len(line) == PER:
            print("   " + "  |  ".join(line))
            line = []
    if line:
        print("   " + "  |  ".join(line))
    print()
