# -*- coding: utf-8 -*-
"""分析缺失 txt 的原因: 超高跳过 / 损坏图 / 其他。"""
import glob, json, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

ranked = sorted(glob.glob("rank-out/ranked*.jsonl"))
rows = []
for rf in ranked:
    for l in open(rf, encoding="utf-8"):
        try:
            rows.append(json.loads(l))
        except Exception:
            pass
rows.sort(key=lambda r: r.get("play", 0), reverse=True)
seen, dirs = set(), []
for r in rows:
    d = os.path.dirname(r["img"])
    if d in seen:
        continue
    seen.add(d)
    dirs.append(d)
dirs = dirs[:1531]

skipped = set()
if os.path.exists("batch-out/skipped.txt"):
    for l in open("batch-out/skipped.txt", encoding="utf-8"):
        if "\t" in l:
            skipped.add(l.split("\t")[0])
errs = ""
if os.path.exists("batch-out/errors.log"):
    errs = open("batch-out/errors.log", encoding="utf-8", errors="ignore").read()

miss = []
for d in dirs:
    name = BT.safe_name(os.path.basename(d))
    if not os.path.exists(f"batch-out/{name}.txt"):
        miss.append((os.path.basename(d), name))
n_skip = n_err = n_other = 0
others = []
for raw, nm in miss:
    if raw in skipped or nm in skipped:
        n_skip += 1
    elif raw in errs or nm in errs:
        n_err += 1
    else:
        n_other += 1
        others.append(nm)
print(f"缺失 {len(miss)}: 超高跳过 {n_skip}, 出错 {n_err}, 其他 {n_other}")
print("其他样例:")
for o in others[:12]:
    print("   ", o[:56])
