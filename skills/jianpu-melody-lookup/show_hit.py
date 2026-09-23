# -*- coding: utf-8 -*-
"""标出「库里这一段(全的)」: 给定曲名与查询串, 把库里**该首歌所有谱**的命中位置连同
原谱 token(带八度/时值记号)打出来, 前后各留上下文。

用法: py -3.13 show_hit.py 神々 637312325
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.stdout.reconfigure(encoding="utf-8")
TOK = re.compile(r"^([qsdh]*)([,']*)([#b]?)([1-7])([,']*)[.]*$")

TITLE_PAT = sys.argv[1] if len(sys.argv) > 1 else "神々"
Q = "".join(c for c in (sys.argv[2] if len(sys.argv) > 2 else "637312325") if c.isdigit())

rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
hits = [r for r in rows if TITLE_PAT in (r.get("title") or "")]
print(f"标题含 {TITLE_PAT!r} 的谱: {len(hits)} 份\n")

for r in hits:
    toks = [t for t in (r.get("score") or "").split() if TOK.match(t)]
    digits = "".join(TOK.match(t).group(4) for t in toks)
    accs = [(TOK.match(t).group(3) or "") for t in toks]
    print(f"=== {r.get('file')}  title={r.get('title')}  音符 {len(toks)}")
    i = digits.find(Q)
    if i < 0:
        # 报最接近的位置(算错音数)
        best = None
        for k in range(len(digits) - len(Q) + 1):
            e = sum(1 for j in range(len(Q)) if digits[k + j] != Q[j])
            if best is None or e < best[0]:
                best = (e, k)
        if best:
            e, k = best
            print(f"   **不含 {Q}**; 最接近在音 {k} 起, 差 {e} 个音")
            i = k
            n = len(Q)
        else:
            print("   谱太短, 跳过")
            continue
    else:
        n = len(Q)
        print(f"   命中 {Q} 在音 {i} 起 (0-based)")
    a, b = max(0, i - 6), min(len(toks), i + n + 6)
    print("   原谱 token(←命中段→):")
    seg = []
    for k in range(a, b):
        mark = "*" if i <= k < i + n and digits[k:k + n] == Q else " "
        seg.append(f"{mark}{toks[k]}")
    print("     " + " ".join(seg))
    print("   命中段纯数字: " + " ".join(digits[i:i + n]))
    print("   命中段带记号: " + " ".join((accs[k] or "") + digits[k] for k in range(i, i + n)))
    print()
