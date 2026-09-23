# -*- coding: utf-8 -*-
"""生成今晚扩库的关键词单 -> train-work/crawl_keywords_night.txt。

两组:
  ① 基准集里**还缺可用转写**的歌 + 只有 batch-out-suspect(质量可疑)版本的歌
     —— 先保证华流金曲100 每首都有干净 通俗简谱;
  ② 候补榜单(bench_availability.tsv, 145 首名人名曲)里**没进基准集**的 45 首
     —— 这是"继续扩大语料"且都是大概率被查的歌。
输出: 每行 `标题|歌手|为什么在这里`
"""
import csv
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")

RESULT_DIRS = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]
SUSPECT = {"batch-out-suspect"}

rows = list(csv.DictReader(open("train-work/bench_availability.tsv", encoding="utf-8"), delimiter="\t"))
final = [l.strip() for l in open("train-work/bench_final100.txt", encoding="utf-8") if l.strip()]
by_title = {r["标题"]: r for r in rows}

picks = []          # (标题, 歌手, 原因)
for r in csv.DictReader(open("train-work/bench_pick.tsv", encoding="utf-8"), delimiter="\t"):
    st = r.get("状态", "")
    if st.startswith("挑"):
        picks.append((r["标题"], by_title.get(r["标题"], {}).get("歌手", ""), "基准集缺谱"))
    elif "suspect" in st:
        picks.append((r["标题"], by_title.get(r["标题"], {}).get("歌手", ""), "基准集只有可疑版本"))

used = set(t for t, _a, _w in picks) | set(final)
spare = [(r["标题"], r["歌手"], "候补名人名曲") for r in rows if r["标题"] not in used]

out = picks + spare
with open("train-work/crawl_keywords_night.txt", "w", encoding="utf-8") as f:
    f.write("# 标题|歌手|原因   (tools/crawl_keywords_night.py 生成)\n")
    for t, a, w in out:
        f.write(f"{t}|{a}|{w}\n")

print(f"待补基准集 {len(picks)} 首: {'、'.join(t for t, _a, _w in picks)}")
print(f"候补扩库 {len(spare)} 首: {'、'.join(t for t, _a, _w in spare[:15])}...")
print(f"合计 {len(out)} 个关键词 -> train-work/crawl_keywords_night.txt")
