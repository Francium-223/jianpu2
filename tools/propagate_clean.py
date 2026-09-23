# -*- coding: utf-8 -*-
"""把清名按**站点 id** 传播到孪生目录。

现象: 同一首曲子常有多个本地目录, 只差一点点:
    一只小花狗钢琴简谱_儿歌演唱__jianpujia-234413
    一只小花狗钢琴简谱_儿歌演唱-简谱__jianpujia-234413      <- 同一个站点页面, 爬了两次
清名表按**目录名**索引, 于是只改了其中一个, 另一个还是脏名字(于是又被标 todo=) ✗。
按 `__站点-id` 兜底: 同一个站点页面 = 同一首歌, 清名应当一致。

用法: py -3.13 tools/propagate_clean.py [--dry]
"""
import csv
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DRY = "--dry" in sys.argv
CLEAN = "train-work/title_clean.tsv"

rows = {}
with open(CLEAN, encoding="utf-8") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        rows[r["目录名"]] = dict(r)

# 站点 id -> 已定的清名(优先取"有变化=1"的)
by_sid = {}
for d, r in rows.items():
    m = re.search(r"__([a-z0-9]+-\d+)$", d)
    if not m:
        continue
    sid = m.group(1)
    if r.get("有变化") == "1" and r.get("模型曲名") not in ("", "?"):
        by_sid[sid] = r["模型曲名"]

# 候选名要**同时**取 batch-out 结果名 —— 有些孪生目录的源目录已经被删掉了,
# 只剩 batch-out 里的转写结果; 而 to_jianpu_db 是拿 batch-out 名去查清名表的, 漏了它就还会脏 ✗
dirs = [os.path.basename(p) for p in glob.glob("images-prep/*/*") if os.path.isdir(p)]
dirs += [os.path.basename(p)[:-4] for p in glob.glob("batch-out/*.txt")]
added, fixed = 0, 0
for d in dirs:
    m = re.search(r"__([a-z0-9]+-\d+)$", d)
    if not m:
        continue
    clean = by_sid.get(m.group(1))
    if not clean:
        continue
    if d not in rows:
        rows[d] = {"目录名": d, "原始名": d.split("__")[0], "模型曲名": clean,
                   "有变化": "1", "原文输出": "propagated-by-site-id"}
        added += 1
    elif rows[d].get("有变化") != "1" and rows[d].get("模型曲名") != clean:
        rows[d]["模型曲名"] = clean
        rows[d]["有变化"] = "1"
        rows[d]["原文输出"] = "propagated-by-site-id"
        fixed += 1

print(f"按站点 id 传播: 新增 {added} 条, 修正 {fixed} 条 (清名表 {len(rows)} 条)")
if DRY:
    sys.exit(0)
with open(CLEAN, "w", encoding="utf-8") as f:
    f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
    for r in rows.values():
        f.write("\t".join(str(r.get(c, "")).replace("\t", " ") for c in
                          ("目录名", "原始名", "模型曲名", "有变化", "原文输出")) + "\n")
print(f"-> {CLEAN}")
