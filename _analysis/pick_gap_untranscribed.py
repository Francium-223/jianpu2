# -*- coding: utf-8 -*-
"""把"榜单缺口曲"在图库里**还没转录**的谱图目录抽成一份名单, 交给 transcribe_source.py。

为什么单独抽: 这些是今晚按曲名定向爬到的**(新页面)**, 不在 plan_next_batch 的老源里;
榜单缺口是最值钱的那批歌, 优先级要高于"回锅目录"。

只读 + 写一份名单(train-work/gap_untranscribed.txt)。
用法: py -3.13 _analysis/pick_gap_untranscribed.py <缺口tsv> [缺口tsv2 ...]
"""
import os
import re
import sys

ROOT = r"D:\Documents_D\jianpu2"
IMGROOTS = [os.path.join(ROOT, "images-prep"), os.path.join(ROOT, "images")]
BOUT = os.path.join(ROOT, "batch-out")
OUTLIST = os.path.join(ROOT, "train-work", "gap_untranscribed.txt")

# 名字里带这些的图基本转不出简谱音符(吉他谱/钢琴谱/五线谱/弹唱/指弹)
BAD = re.compile(r"吉他|指弹|钢琴|五线谱|弹唱|六线|ukulele|尤克里里|架子鼓|教学|双谱|正谱|总谱|简线|线简|ukulele", re.I)


def norm(s):
    return re.sub(r"[\s（）()【】\[\]·,，.。!！?？'\"“”‘’\-—_/\\|~～:：;；&]", "", s).lower()


def imgdirs():
    out = []
    for r in IMGROOTS:
        if not os.path.isdir(r):
            continue
        for d in os.listdir(r):
            p = os.path.join(r, d)
            if not os.path.isdir(p):
                continue
            if "__" in d and re.search(r"__(jianpu|qupu|jpcn|jpjia)", d):
                out.append(d)
                continue
            for e in os.listdir(p):
                q = os.path.join(p, e)
                if os.path.isdir(q) and "__" in e:
                    out.append(e)
    return out


D = imgdirs()
have = {os.path.splitext(f)[0] for f in os.listdir(BOUT) if f.endswith(".txt")}
picked, seen, stat = [], set(), []
for tsv in sys.argv[1:]:
    listname = os.path.basename(tsv).replace("榜单缺口_", "").replace(".tsv", "")
    for line in open(tsv, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = re.split(r"\t+", line)
        title = re.sub(r"[（(].*?[)）]", "", parts[0]).strip()
        if title in ("曲名", ""):
            continue
        nt = norm(title)
        if not nt:
            continue
        hits = [d for d in D if nt in norm(d)]
        fresh = [d for d in hits if d not in have]
        good = [d for d in fresh if not BAD.search(d)]
        stat.append((listname, title, len(hits), len(fresh), len(good)))
        for d in good:
            if d not in seen:
                seen.add(d)
                picked.append(d)

with open(OUTLIST, "w", encoding="utf-8") as f:
    for d in picked:
        f.write(d + "\n")

print(f"图库 {len(D)} 个目录 · 已转录 {len(have)} 份")
print(f"{'榜单':<34}{'曲名':<14}{'图库':>4}{'没转录':>6}{'可试转':>6}")
for listname, title, n, fr, gd in stat:
    if fr:
        print(f"{listname:<34}{title:<14}{n:>4}{fr:>6}{gd:>6}")
print(f"\n名单 -> {OUTLIST}  ({len(picked)} 个目录)")
for d in picked:
    print("   " + d)
