# -*- coding: utf-8 -*-
"""抽查"回锅后变短"的稿子：**哪些是真的被判据截断了**，哪些是旧稿本来就虚高。

为什么需要: 回锅（多页拼接重转）之后 `_analysis/compare_multipage.py` 会报"变短 N 份"，
但"变短"有三种可能 —— ① 判据把页丢了（**要修**）② 旧稿把和弦谱/五线谱页拼进来了（旧稿虚高，新的才对）
③ 两版本来就不同（换了一页/换了版本）。这个脚本把 ① 挑出来：**看 sidecar 里 dropped_pages>0 或
整份被判织体的**，再按"掉了多少音"排序。

用法:
  py -3.13 tools/qa_shorter_after_redo.py [--top 20] [--mine 200]
"""
import argparse
import glob
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = os.path.join(ROOT, "batch-out-multipage-old")
NEW = os.path.join(ROOT, "batch-out")


def notes(path):
    try:
        t = io.open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    return sum(1 for x in t.split() if re.search(r"[1-7]", x))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--mine", type=int, default=200, help="差额小于这个数就不看（噪声）")
    a = ap.parse_args()

    rows = []
    for p in glob.glob(os.path.join(OLD, "*.txt")):
        nm = os.path.basename(p)[:-4]
        cur = os.path.join(NEW, nm + ".txt")
        if not os.path.exists(cur):
            continue
        o, n = notes(p), notes(cur)
        if o is None or n is None or o - n < a.mine:
            continue
        side = os.path.join(NEW, nm + ".json")
        dropped, pages, pn = "", "", ""
        if os.path.exists(side):
            try:
                d = json.load(io.open(side, encoding="utf-8"))
                dropped = d.get("dropped_pages", "")
                pages = d.get("pages", "")
                pn = d.get("page_notes", "")
            except Exception:
                pass
        rows.append((o - n, o, n, nm, dropped, pages, pn))

    rows.sort(reverse=True)
    print(f"回锅后『变短』且差额 >= {a.mine} 音的: **{len(rows)}** 份\n")
    by_drop = [r for r in rows if r[4] not in ("", 0)]
    print(f"其中 sidecar 说**真丢了页**的: **{len(by_drop)}** 份（这些要补转/要查判据）")
    for d, o, n, nm, dr, pg, pn in by_drop[:a.top]:
        print(f"   -{d:<5} {o:>5} -> {n:<5} 丢{dr}页/{pg}页  page_notes={pn}")
        print(f"        {nm[:70]}")
    rest = [r for r in rows if r[4] in ("", 0)]
    print(f"\n其余 {len(rest)} 份 sidecar 说没丢页（多半是旧稿虚高或换版）:")
    for d, o, n, nm, dr, pg, pn in rest[:a.top]:
        print(f"   -{d:<5} {o:>5} -> {n:<5} 页={pg}  {nm[:60]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
