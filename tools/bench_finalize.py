# -*- coding: utf-8 -*-
"""把 bench_availability.tsv 收口成最终基准集: 按原列表顺序(名气优先)取前 N 首"确实有简谱"的。
判定"有简谱" = (曲谱站通俗简谱>0) 或 (本地有谱目录>0) 或 (本地已转写>0)。
用法: py -3.13 tools/bench_finalize.py [N] [可用性tsv] [候选列表]
产物: train-work/bench_final100.tsv + bench_final100.txt(纯曲名, 可直接喂爬虫/转写)
"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 100
TSV = sys.argv[2] if len(sys.argv) > 2 else "train-work/bench_availability.tsv"
PREFIX = "train-work/bench_final100"

rows = []
with open(TSV, encoding="utf-8") as f:
    head = f.readline()
    for line in f:
        p = line.rstrip("\n").split("\t")
        if len(p) < 7:
            continue
        rows.append({"标题": p[0], "歌手": p[1], "qupu": int(p[2] or 0), "器乐": int(p[3] or 0),
                     "本地目录": int(p[5] or 0), "本地已转": int(p[6] or 0)})

final, dropped = [], []
for r in rows:
    ok = r["qupu"] > 0 or r["本地目录"] > 0 or r["本地已转"] > 0
    (final if ok else dropped).append(r)

final = final[:N]
print(f"候选 {len(rows)}   有谱 {sum(1 for r in rows if r['qupu'] or r['本地目录'] or r['本地已转'])}   "
      f"取前 {len(final)} 首\n")

n_site = sum(1 for r in final if r["qupu"] > 0)
n_local = sum(1 for r in final if r["本地目录"] or r["本地已转"])
n_both = sum(1 for r in final if r["qupu"] > 0 and (r["本地目录"] or r["本地已转"]))
print(f"最终基准集 {len(final)} 首：站上有通俗简谱 {n_site}，本地已有 {n_local}，两边都有 {n_both}")
print(f"（另有 {len(dropped)} 首查无通俗简谱，已剔除；可留作'可得性'说明）\n")

with open(f"{PREFIX}.tsv", "w", encoding="utf-8") as f:
    f.write("序号\t标题\t歌手\t曲谱站通俗\t本地目录\t本地已转\n")
    for i, r in enumerate(final, 1):
        f.write(f"{i}\t{r['标题']}\t{r['歌手']}\t{r['qupu']}\t{r['本地目录']}\t{r['本地已转']}\n")
with open(f"{PREFIX}.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(r["标题"] for r in final) + "\n")

print("前 30 首：")
for i, r in enumerate(final[:30], 1):
    print(f"  {i:3d}. {r['标题']:<16} {r['歌手']:<8} 站{r['qupu']:>2} 本地{r['本地目录']:>2}/已转{r['本地已转']:>2}")
print(f"\n已存 {PREFIX}.tsv / {PREFIX}.txt")
