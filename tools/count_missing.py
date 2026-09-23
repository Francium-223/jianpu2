# -*- coding: utf-8 -*-
"""统计: 批次目标(前1531个目录)里有多少没有 txt, 以及原因(非法文件名/损坏图/跳过)。"""
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

no_txt = []
for d in dirs:
    name = BT.safe_name(os.path.basename(d))
    if not os.path.exists(f"batch-out/{name}.txt"):
        no_txt.append(name)
print(f"批次目标 {len(dirs)} 个目录, 缺 txt {len(no_txt)} 个\n")
# 分类原因
badname = [n for n in no_txt if re.search(r"[\x00-\x1f\x7f-\x9f]", n)]
moji = [n for n in no_txt if re.search(r"[Â-ÿ]", n)]
print(f"  文件名含控制字符(写入必失败): {len(badname)}")
print(f"  文件名含 mojibake 高位字符:   {len(moji)}")
for n in no_txt[:12]:
    try:
        ctrl = bool(re.search(r"[\x00-\x1f\x7f-\x9f]", n))
    except Exception:
        ctrl = False
    print(f"    [ctrl={ctrl}] {n[:52]}")
