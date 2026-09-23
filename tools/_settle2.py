# -*- coding: utf-8 -*-
"""钉死矛盾: 同一份 data.jsonl, jptok.seq 与 lookup_norm 的 norm_digits 结果为何不同?"""
import io
import json
import os
import re
import sys

HERE = r"D:\Documents_D\jianpu2\skills\jianpu-melody-lookup"
sys.path.insert(0, HERE)
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402
import lookup_norm as LN  # noqa: E402

Q = "33565653253"
rows = [json.loads(l) for l in io.open(os.path.join(HERE, "data.jsonl"), encoding="utf-8") if l.strip()]
hits = [r for r in rows if "神々" in (r.get("title") or "")]
print(f"data.jsonl 里标题含「神々」: {len(hits)} 份")
for r in hits:
    sc = r.get("score") or ""
    a = "".join(str(d) for d, _x, _y in jptok.seq(sc))              # jptok 口径
    b = LN.norm_digits(sc)[0]                                        # lookup_norm 口径
    print(f"  {r['file'][0]}  jptok 长度 {len(a)}   另一口径长度 {len(b)}   两口径相同? {a == b}")
    print(f"    jptok  含 {Q}? {Q in a}   位置 {a.find(Q)}")
    print(f"    另一口径 含 {Q}? {Q in b}   位置 {b.find(Q)}")
    if Q in b:
        i = b.find(Q)
        print(f"    另一口径 上下文: ...{b[max(0,i-12):i+len(Q)+12]}...")
    # 两串首个不同点
    for k in range(min(len(a), len(b))):
        if a[k] != b[k]:
            print(f"    首处分歧 @{k}: jptok={a[max(0,k-6):k+10]!r}  另一={b[max(0,k-6):k+10]!r}")
            break
    else:
        print("    前缀完全一致")
    print(f"    score 前 160: {sc[:160]}")
