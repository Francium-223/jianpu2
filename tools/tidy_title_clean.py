# -*- coding: utf-8 -*-
"""后处理: 把 title_clean(_part).tsv 里的**书名号**去掉, 并重算"有变化"。

用户口径(2026-09-22): "书名号也不要有。" —— 《情人》-> 情人, Beyond《不再犹豫》-> 不再犹豫。
模型那一步是流式跑的, 改 prompt 对已经在跑的进程没用, 所以这里做**确定性**收尾。

用法: py -3.13 tools/tidy_title_clean.py [--file train-work/title_clean.tsv]
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
from refine_titles_llm import clean_one, ok

MARKS = "《》〈〉"


def tidy(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines:
        return None
    rows, hit, bad = [], 0, 0
    for ln in lines[1:]:
        p = ln.split("\t")
        if len(p) < 5:
            continue
        full, orig, got, _ch, raw = p[0], p[1], p[2], p[3], "\t".join(p[4:])
        new = clean_one(got) if got != "?" else "?"
        if any(m in got for m in MARKS) and new != got:
            hit += 1
        if new != "?" and not ok(orig, new):
            new, bad = "?", bad + 1
        rows.append((full, orig, new, "1" if new not in ("?", orig) else "0", raw))
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
        for r in rows:
            f.write("\t".join(str(x).replace("\t", " ") for x in r) + "\n")
    os.replace(tmp, path)
    ex = [r for r in rows if any(m in r[2] for m in MARKS)][:3]
    print(f"{path}: {len(rows)} 行, 书名号去掉 {hit} 条, 复核不过 {bad} 条"
          + (f"  残留示例 {ex}" if ex else ""), flush=True)
    return rows


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default="train-work/title_clean.tsv")
    a = ap.parse_args()
    got = {}
    for p in (a.file, "train-work/title_clean.part.tsv"):
        r = tidy(p)
        got[p] = r
        if r is None:
            print(f"{p}: 不存在, 跳过", flush=True)
    rows = got.get(a.file) or []
    ch = sum(1 for r in rows if r[3] == "1")
    print(f"\n合计: 有改动 {ch}/{len(rows)}", flush=True)
