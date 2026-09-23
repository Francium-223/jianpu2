# -*- coding: utf-8 -*-
"""用正确口径(jptok, 逐 token)**重新定案**: 33565653253 到底在不在库里、最接近谁。

顺带对比"坏口径"(整段抠数字)的结果, 把差异量化 —— 证明之前的矛盾来自解析器而非数据。
"""
import io
import json
import os
import sys

HERE = r"D:\Documents_D\jianpu2\skills\jianpu-melody-lookup"
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402
import lookup_norm as LN  # noqa: E402

Q = sys.argv[1] if len(sys.argv) > 1 else "33565653253"
qd = [str(d) for d, _a, _o in jptok.query(Q)]
rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
print(f"查询 {Q}  ({len(qd)} 音)\n")

# 全库: 正确口径的 0 错命中
exact, near = [], []
for r in rows:
    sc = r.get("score") or ""
    p = "".join(str(d) for d, _a, _o in jptok.seq(sc))
    i = p.find("".join(qd))
    if i >= 0:
        exact.append((r.get("title"), r.get("file")[0], i))
        continue
    n = len(qd)
    best = None
    for k in range(max(0, len(p) - n + 1)):
        e = sum(1 for j in range(n) if p[k + j] != qd[j])
        if best is None or e < best[0]:
            best = (e, k)
    if best and best[0] <= 1:
        near.append((best[0], r.get("title"), r.get("file")[0], p[best[1]:best[1] + n]))

print(f"[正确口径 jptok] 0 错命中: {len(exact)} 首")
for t, f, i in exact[:8]:
    print(f"    {t}  ({f})  位置 {i}")
print(f"[正确口径 jptok] 差 1 音的: {len(near)} 首")
for e, t, f, seg in sorted(near)[:8]:
    print(f"    差{e}  {t:<20} {f:<26} 库内 {seg}")

# 坏口径对比
bad_exact = 0
for r in rows:
    sc = r.get("score") or ""
    b = LN.norm_digits(sc)[0] if sc else ""
    if "".join(qd) in b:
        bad_exact += 1
print(f"\n[坏口径 norm_digits] 0 错命中: {bad_exact} 首  ← 这个数虚高, 是解析器造的")
