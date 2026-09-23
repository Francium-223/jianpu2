# -*- coding: utf-8 -*-
"""最终交付统计。"""
import glob, os, re, sys, collections
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")
fs = sorted(glob.glob("jianpu-db-out/scores/*.txt"))
meters = collections.Counter()
nm = nt = tot = dbl = 0
for f in fs:
    t = open(f, encoding="utf-8").read()
    m = re.search(r"^(\d+/\d+)$", t, re.M)
    meters[m.group(1) if m else "?"] += 1
    if re.search(r"^MBID=\S", t, re.M):
        nm += 1
    if "%TODO" in t:
        nt += 1
    body = t.split("%--", 1)[-1]
    tot += len([x for x in body.split() if NOTE.match(x)])
    dbl += t.count("''")

print(f"jianpu-db 曲谱: {len(fs)} 个   总音符 {tot}")
print(f"拍号分布: {dict(meters.most_common())}")
print(f"有 MBID: {nm}    占位(%TODO): {nt}")
print(f"双高八度残留: {dbl}")

# 抽样展示
print("\n=== 样例(前2个) ===")
for f in fs[:2]:
    t = open(f, encoding="utf-8").read().splitlines()
    print("\n".join(t[:11]))
    print("...")
