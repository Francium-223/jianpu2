# -*- coding: utf-8 -*-
"""标出「库里这一段(全的)」: 给定曲名与查询串, 把库里**该首歌所有谱**的命中位置连同
原谱 token(带八度/时值记号)打出来, 前后各留上下文。

用法: py -3.13 show_hit.py 神々 637312325

口径: 一律走 jptok(和检索脚本同一个 token 解析器), 不再自带正则。
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

TITLE_PAT = sys.argv[1] if len(sys.argv) > 1 else "神々"
Q = jptok.query(sys.argv[2] if len(sys.argv) > 2 else "637312325")
QD = [str(d) for d, _a, _o in Q]

rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
hits = [r for r in rows if TITLE_PAT in (r.get("title") or "")]
print(f"标题含 {TITLE_PAT!r} 的谱: {len(hits)} 份   查询 {jptok.show(Q)} ({len(QD)} 音)\n")

for r in hits:
    notes = jptok.seq(r.get("score") or "")
    digits = [str(d) for d, _a, _o in notes]
    print(f"=== {r.get('file')}  title={r.get('title')}  音符 {len(notes)}")
    n = len(QD)
    i = -1
    for k in range(len(digits) - n + 1):
        if digits[k:k + n] == QD:
            i = k
            break
    if i < 0:
        # 报最接近的位置(算错音数)
        best = None
        for k in range(max(0, len(digits) - n + 1)):
            e = sum(1 for j in range(n) if digits[k + j] != QD[j])
            if best is None or e < best[0]:
                best = (e, k)
        if best:
            e, k = best
            print(f"   **不含 {jptok.show(Q)}**; 最接近在音 {k} 起, 差 {e} 个音")
            i = k
        else:
            print("   谱太短, 跳过")
            continue
    else:
        print(f"   命中 {jptok.show(Q)} 在音 {i} 起 (0-based)")
    a, b = max(0, i - 6), min(len(notes), i + n + 6)
    print("   原谱 token(←命中段→):")
    seg = []
    for k in range(a, b):
        mark = "*" if i <= k < i + n and digits[k:k + n] == QD else " "
        seg.append(f"{mark}{jptok.show([notes[k]])}")
    print("     " + " ".join(seg))
    print("   命中段纯数字: " + " ".join(digits[i:i + n]))
    print("   命中段带记号: " + jptok.show(notes[i:i + n]))
    print()
