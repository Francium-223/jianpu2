# -*- coding: utf-8 -*-
"""验证重建后的数据自洽: data.jsonl 与 scores/*.txt 的音符数是否一致 + source 覆盖。"""
import io
import json
import random
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
TOK = re.compile(r"^[,']*[qsdh]*[,']*[0-9x]")
rows = [json.loads(l) for l in io.open(r"D:\Documents_D\jianpu-db\data.jsonl", encoding="utf-8") if l.strip()]
nsrc = sum(1 for r in rows if r.get("source"))
print(f"data.jsonl {len(rows)} 行; 有 source 的 {nsrc} ({nsrc/len(rows)*100:.1f}%)")

bad = 0
for r in random.Random(1).sample(rows, 8):
    f = r"D:\Documents_D\jianpu-db\scores" + "\\" + r["file"][0]
    try:
        raw = io.open(f, encoding="utf-8", errors="replace").read()
    except Exception as e:
        print(f"  {r['file'][0]:<30} 读不到: {type(e).__name__}")
        continue
    n1 = len([t for t in raw.split() if TOK.match(t)])
    n2 = len([t for t in (r.get("score") or "").split() if TOK.match(t)])
    ok = "OK" if n1 == n2 else "**不一致**"
    if n1 != n2:
        bad += 1
    print(f"  {r['file'][0]:<30} 文件 {n1:>5}  jsonl {n2:>5}  {ok}")
print("抽查不一致:", bad)
