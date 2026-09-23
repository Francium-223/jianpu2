# -*- coding: utf-8 -*-
"""修脏曲名: 把 `title=` 恰好等于歌手名的那些, 从原始下载目录名里救回真名。

目录形态实测: `邓丽君演唱金曲： 情湖__qupu123-292101` -> 真名 = 冒号之后、`__` 之前的部分。
只改曲谱文件里的 `title=` 行(并把原值记进 `%` 注释), **不动文件名**(file 是稳定标识)。
同时把修正写进 train-work/title_clean.tsv 的"模型曲名"列, 否则下一次重建又被冲刷回去。

用法: py -3.13 tools/fix_artist_titles.py [--apply]
"""
import glob
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
APPLY = "--apply" in sys.argv
DB = r"D:\Documents_D\jianpu-db"

byname = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        n = os.path.basename(d)
        m = re.search(r"__([a-z0-9]+)-([0-9a-z_]+)$", n)
        if m:
            byname.setdefault(m.group(1) + "-" + m.group(2), n)

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

rows = [json.loads(l) for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8") if l.strip()]
plan = []
for r in rows:
    t = (r.get("title") or "").strip()
    if not t or t not in arts:
        continue
    s = r.get("source") or ""
    s = s[0] if isinstance(s, list) else s
    raw = byname.get(s, "")
    real = ""
    if raw:
        m = re.search(r"[：:]\s*([^_＿]{1,40}?)(?:__|$)", raw)
        if m:
            real = m.group(1).strip()
    if real and real != t:
        plan.append((r["file"][0], t, real, s))

print(f"待修 {len(plan)} 首 (title=歌手名 -> 目录名里的真名)")
for f, old, new, s in plan[:10]:
    print(f"   {f:<20} {old} -> {new}   {s}")

if not APPLY:
    print("\n(未落盘; 加 --apply 才改)")
    sys.exit(0)

fixed = 0
for f, old, new, s in plan:
    p = os.path.join(DB, "scores", f)
    if not os.path.exists(p):
        continue
    raw = io.open(p, encoding="utf-8", errors="replace", newline="").read()
    nl = "\r\n" if "\r\n" in raw else "\n"
    out, done = [], False
    for ln in raw.split(nl):
        if not done and ln.strip() == "title=" + old:
            out.append("title=" + new)
            out.append(f"% 原 title={old} (爬虫把歌手名当成了曲名, 已按目录名修正)")
            done = True
            continue
        out.append(ln)
    if done:
        io.open(p, "w", encoding="utf-8", newline="").write(nl.join(out))
        fixed += 1
print(f"已修 {fixed} 首曲谱文件")

# 同步 title_clean 缓存, 否则下次重建又脏回去
import shutil
for src in ("train-work/title_clean.tsv", "train-work/title_clean.part.tsv"):
    if not os.path.exists(src):
        continue
    lines = io.open(src, encoding="utf-8").read().split("\n")
    newlines, n = [], 0
    for ln in lines:
        c = ln.split("\t")
        if len(c) >= 4:
            t = (c[2] or "").strip()
            if t and t in arts:
                s2 = None
                for ff, old, new, ss in plan:
                    if t == old:
                        s2 = new
                        break
                if s2:
                    c[2] = s2
                    c[3] = "1"
                    n += 1
                    ln = "\t".join(c)
        newlines.append(ln)
    io.open(src, "w", encoding="utf-8", newline="\n").write("\n".join(newlines))
    print(f"{src}: 修正 {n} 行")
