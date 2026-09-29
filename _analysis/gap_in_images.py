# -*- coding: utf-8 -*-
"""抽检: 榜单缺口曲在**图库**里是否已经下到、以及有没有转录稿。

只读。用法: py -3.13 _analysis/gap_in_images.py <缺口tsv> [缺口tsv2 ...]
缺口 tsv 由 tools/diagnose_list_coverage.py 生成(列: 曲名<TAB>歌手 或 曲名(歌手))。
"""
import os
import re
import sys

ROOT = r"D:\Documents_D\jianpu2"
IMGROOTS = [os.path.join(ROOT, "images-prep"), os.path.join(ROOT, "images")]
BOUT = os.path.join(ROOT, "batch-out")


def norm(s):
    s = re.sub(r"[\s（）()【】\[\]·,，.。!！?？'\"“”‘’\-—_/\\|~～:：;；]", "", s)
    return s.lower()


def dirs():
    """谱图目录一般在 images-prep/<源>/<曲名>__<站点>-<id>/ (也可能是再浅一层)。"""
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


D = dirs()
have_txt = {os.path.splitext(f)[0] for f in os.listdir(BOUT) if f.endswith(".txt")}
print(f"图库目录 {len(D)} 个 · 转录稿 {len(have_txt)} 份")

for tsv in sys.argv[1:]:
    print(f"\n### {os.path.basename(tsv)}")
    for line in open(tsv, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = re.split(r"\t+", line)
        title = re.sub(r"[（(].*?[)）]", "", parts[0]).strip()
        singer = parts[1].strip() if len(parts) > 1 else ""
        nt, ns = norm(title), norm(singer)
        hits = [d for d in D if nt and nt in norm(d) and (not ns or ns in norm(d) or len(ns) < 2)]
        if not hits:
            hits = [d for d in D if nt and nt in norm(d)]
        state = []
        for d in hits[:4]:
            state.append(f"{d[:46]}{'[已转录]' if d in have_txt else '[没转录]'}")
        print(f"  {title}({singer}): 图库 {len(hits)} 个 -> " + (" | ".join(state) if state else "没下到"))
