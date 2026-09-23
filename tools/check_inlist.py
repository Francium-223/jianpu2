# -*- coding: utf-8 -*-
"""确认这几个目录是否在 batch 的目标列表(热度排序)里。"""
import glob, json, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

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
    dd = os.path.dirname(r["img"])
    if dd in seen:
        continue
    seen.add(dd)
    dirs.append(dd)

for key in ["15847", "15571", "15680", "15745", "15563", "15551", "15574", "334061"]:
    hit = [i for i, d in enumerate(dirs) if key in d]
    print(f"{key}: 在热度列表位置 {hit[0] if hit else '不在'}  (总 {len(dirs)})")
print(f"\n热度列表共 {len(dirs)} 个目录; 批处理范围 0..1531")
