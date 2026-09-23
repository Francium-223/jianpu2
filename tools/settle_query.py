# -*- coding: utf-8 -*-
"""定案: data.jsonl 里标题含「神々」的谱, 其音高串到底含不含 33565653253?

不依赖任何检索脚本, 直接读文件算 —— 排除"是检索代码的问题"这个可能。
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, r"D:\Documents_D\jianpu2\skills\jianpu-melody-lookup")
sys.stdout.reconfigure(encoding="utf-8")
import jptok  # noqa: E402

Q = sys.argv[1] if len(sys.argv) > 1 else "33565653253"
qd = [str(d) for d, _a, _o in jptok.query(Q)]
PATH = r"D:\Documents_D\jianpu-db\data.jsonl"
print(f"查询 {Q} -> 音级串 {''.join(qd)}   数据 {PATH}  ({os.path.getmtime(PATH)})")

rows = [json.loads(l) for l in io.open(PATH, encoding="utf-8") if l.strip()]
hits = [r for r in rows if "神々" in (r.get("title") or "")]
print(f"标题含「神々」的谱: {len(hits)} 份")
for r in hits:
    p = "".join(str(d) for d, _a, _o in jptok.seq(r.get("score") or ""))
    i = p.find("".join(qd))
    print(f"  {r['file'][0]:<16} 音符 {len(p):<5} 含查询串? {i >= 0}" + (f"  位置 {i}" if i >= 0 else ""))
    if i >= 0:
        print(f"      上下文: {p[max(0,i-10):i+len(qd)+10]}")
    else:
        # 报最接近的窗口
        n = len(qd)
        best = None
        for k in range(max(0, len(p) - n + 1)):
            e = sum(1 for j in range(n) if p[k + j] != qd[j])
            if best is None or e < best[0]:
                best = (e, k)
        if best:
            print(f"      最接近@ {best[1]} 差 {best[0]} 音: {p[best[1]:best[1]+n]}")

# 全库再确认一次
tot = 0
for r in rows:
    p = "".join(str(d) for d, _a, _o in jptok.seq(r.get("score") or ""))
    if "".join(qd) in p:
        tot += 1
print(f"\n全库({len(rows)} 首)含该串的: {tot} 首")
