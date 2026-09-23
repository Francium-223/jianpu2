# -*- coding: utf-8 -*-
"""查: 库里 1034 份带 MBID 的曲谱, 为什么只有 35 条进了 data.jsonl?"""
import collections
import glob
import io
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
DB = r"D:\Documents_D\jianpu-db"
st = collections.Counter()
by_id = {}
n = 0
for f in glob.glob(DB + r"\scores\*.txt"):
    if f.endswith("_expand.txt"):
        continue
    t = io.open(f, encoding="utf-8", errors="replace").read()
    if not re.search(r"(?m)^MBID=", t):
        continue
    n += 1
    m = re.search(r"(?m)^status=(.*)$", t)
    s = (m.group(1).strip() if m else "(无 status)")
    st[s] += 1
    by_id[f.split("\\")[-1]] = s

print(f"带 MBID 的曲谱 {n} 份; 按 status 分布:")
for k, v in st.most_common():
    print(f"   {k:<12} {v}")

rows = {}
for l in io.open(DB + r"\data.jsonl", encoding="utf-8"):
    r = json.loads(l)
    rows[r["file"][0]] = r
in_jsonl = [k for k in by_id if k in rows]
with_mbid = [k for k in in_jsonl if rows[k].get("MBID")]
print(f"\n这些文件里进了 data.jsonl 的: {len(in_jsonl)}; 其中 MBID 字段非空: {len(with_mbid)}")
# 抽一个进了 jsonl 但 MBID 为空的看
for k in in_jsonl:
    if not rows[k].get("MBID"):
        print(f"  进了但 MBID 空: {k}  (库里 status={by_id[k]})")
        break
