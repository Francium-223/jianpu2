#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""审计「被纯度门挡下的改编/器乐谱」——给"要不要放宽口径"这个待定项提供事实。

背景(锦囊 §8-5): 39 首吉他/钢琴改编谱因过不了纯度门被排除在语料外。纯度门判的**不是音乐质量**,
而是**图像里有没有五线谱/六线谱**(`kind2.tsv` 的 pure=0)。本脚本把整个被挡的类别量化清楚:

  * 被挡总数 / 其中名字像改编器乐的有多少
  * 这些**图在不在** `images-prep` 里(能重转写就有戏) —— 注意图是嵌在分类子目录下的
  * 有多少是**语料里还没有的新曲**(收了能净增), 多少只是"同一首的另一个版本"
  * 有多少有**核对过的原谱页 URL**(能人工看图快速判断)

用法:
  python3 jianpu2/tools/audit_arrangements.py                 # 出清单 + 统计
  python3 jianpu2/tools/audit_arrangements.py --out x.tsv
"""
import argparse
import collections
import csv
import glob
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                          # jianpu2/
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")

ARR = re.compile(r"吉他|钢琴|双手|五线谱|伴奏|指法|编配|弹唱|总谱|萨克斯|古筝|琵琶|二胡|"
                 r"笛|尤克里里|器乐|双谱|简线|独奏|教学")
ID_RE = re.compile(r"__([a-z0-9]+-\d+)$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", default=os.path.join(ROOT, "train-work", "kind2.tsv"))
    ap.add_argument("--out", default=os.path.join(WS, "_analysis", "arrangement_candidates.tsv"))
    a = ap.parse_args()

    rows = list(csv.DictReader(io.open(a.kind, encoding="utf-8"), delimiter="\t"))
    impure = [r for r in rows if (r.get("pure") or "") == "0"]
    arr = [r for r in impure if ARR.search(r.get("dir") or "")]

    # 语料已有的 source
    srcs = set()
    for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
        r = json.loads(l)
        s = r.get("source") or []
        s = s[0] if isinstance(s, list) and s else ""
        if s:
            srcs.add(s)
    sp = {}
    p = os.path.join(DB, "source_pages.json")
    if os.path.isfile(p):
        sp = json.load(io.open(p, encoding="utf-8"))

    # 图在哪: images-prep 里按 `<名字>__<site>-<id>` 找(嵌在分类子目录下)
    out, stat = [], collections.Counter()
    for r in arr:
        d = r["dir"]
        m = ID_RE.search(d)
        sid = m.group(1) if m else ""
        hits = glob.glob(os.path.join(WS, "images-prep", "*", d)) or \
            glob.glob(os.path.join(WS, "images-prep", d))
        stat["有图" if hits else "没图"] += 1
        stat["语料已有该 source" if sid and sid in srcs else "语料里是新曲"] += 1
        if sid in sp:
            stat["有核对过的原谱页"] += 1
        out.append((d, hits[0].replace(WS + "/", "") if hits else "",
                    sid, "1" if sid in srcs else "0",
                    r.get("nline", ""), r.get("staff", ""), sp.get(sid, {}).get("url", "")))

    io.open(a.out, "w", encoding="utf-8", newline="\n").write(
        "dir\tpath_in_images_prep\tsource\tin_corpus\tnline\tstaff\tsource_url\n" +
        "\n".join("\t".join(x) for x in out) + "\n")
    print("被纯度门挡下(impure): %d 个目录" % len(impure))
    print("其中名字像改编/器乐/双谱的: %d" % len(arr))
    for k, v in sorted(stat.items()):
        print("   %-22s %d" % (k, v))
    print("清单: %s" % a.out)
    print()
    print("结论口径: 『有图 + 语料里是新曲』的那批才是『放宽口径』能净增的曲;")
    print("          『语料已有该 source』的收了只是多一个版本(可用于替换更差的版本)。")
    print("重转写需要视觉模型(Ollama + qwen2.5vl, 见锦囊 §4), 本机没装。")


if __name__ == "__main__":
    sys.exit(main())
