# -*- coding: utf-8 -*-
"""jianpu-db 输出成果最终统计。"""
import collections, glob, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")
fs = sorted(glob.glob("jianpu-db-out/scores/*.txt"))
meters = collections.Counter()
tot = n_mbid = n_wd = n_none = 0
for f in fs:
    t = open(f, encoding="utf-8").read()
    m = re.search(r"^(\d+/\d+)$", t, re.M)
    meters[m.group(1) if m else "?"] += 1
    body = t.split("%--", 1)[-1]
    tot += len([x for x in body.split() if NOTE.match(x)])
    if re.search(r"^MBID=\S", t, re.M):
        n_mbid += 1
    elif re.search(r"^Wikidata=\S", t, re.M):
        n_wd += 1
    else:
        n_none += 1

print(f"jianpu-db 格式曲谱: {len(fs)} 个")
print(f"  总音符: {tot:,}")
print(f"  拍号分布: {dict(meters.most_common())}")
print(f"  带 MBID: {n_mbid}   带 Wikidata: {n_wd}   无标识: {n_none}")
