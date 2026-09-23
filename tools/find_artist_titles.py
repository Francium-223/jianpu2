# -*- coding: utf-8 -*-
"""统计并列出"曲名被存成歌手名"的脏数据, 并从原始下载目录名里救回真名。

目录形态(实测): `邓丽君演唱金曲： 情湖__qupu123-292101`
  -> 真曲名 = 冒号后面的部分(`情湖`); 冒号前是专辑/歌手说明。
"""
import glob
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")

# source -> 原始目录名
byname = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        n = os.path.basename(d)
        m = re.search(r"__([a-z0-9]+)-([0-9a-z_]+)$", n)
        if m:
            byname.setdefault(m.group(1) + "-" + m.group(2), n)

rows = [json.loads(l) for l in io.open(r"D:\Documents_D\jianpu-db\data.jsonl", encoding="utf-8") if l.strip()]
arts = set()
for p in ("train-work/artist_pages.txt", "train-work/artist_pages2.txt"):
    if os.path.exists(p):
        for ln in io.open(p, encoding="utf-8"):
            c = ln.split("\t")
            if c and c[0].strip():
                arts.add(c[0].strip())
for ln in io.open("train-work/jianpujia_artists.tsv", encoding="utf-8"):
    c = ln.rstrip("\n").split("\t")
    if len(c) == 2 and c[0].strip():
        arts.add(c[0].strip())

hit = []
for r in rows:
    t = (r.get("title") or "").strip()
    if t and t in arts:
        s = r.get("source") or ""
        s = s[0] if isinstance(s, list) else s
        raw = byname.get(s, "")
        real = ""
        if raw:
            m = re.search(r"[：:]\s*([^_＿]{1,40}?)(?:__|$)", raw)
            if m:
                real = m.group(1).strip()
        hit.append((r["file"][0], t, s, real, r.get("n_notes")))

print(f"曲名 = 歌手名 的脏数据: {len(hit)} 首")
savable = [h for h in hit if h[3]]
print(f"  其中能从目录名救回真名: {len(savable)}")
print(f"  救不回的: {len(hit)-len(savable)}")
print("\n前 15 条:")
for f, t, s, real, n in hit[:15]:
    print(f"  {f:<22} title={t:<8} -> 真名 {real or '(救不回)':<12} {s}  {n} 音")
