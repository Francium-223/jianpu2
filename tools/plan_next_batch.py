# -*- coding: utf-8 -*-
"""挑下一批要转写的谱: 从各源**还没转过的**目录里按源均摊挑, 出一份名单(给 transcribe_source.py 用)。

为什么要均摊: 一直按"最大源"转(如 jianpucn-pop 一个人就有 1936 个没转) 会让新入库的歌**全挤在一个源**,
检索榜单一测就容易过拟合单站口径; 各源都进一点, 才叫"扩大语料"而不是"堆一个站"。

用法:
    py -3.13 tools/plan_next_batch.py --per-source 60 --max-total 720 --out train-work/next_batch.txt
"""
import argparse
import glob
import io
import os
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-source", type=int, default=60)
    ap.add_argument("--min-left", type=int, default=10, help="该源未转数少于此就不挑(避免碎批)")
    ap.add_argument("--max-total", type=int, default=720)
    ap.add_argument("--out", default=os.path.join(ROOT, "train-work", "next_batch.txt"))
    a = ap.parse_args()

    have = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "batch-out")) if f.endswith(".txt")}
    # 先按"未转数从多到少"排源, 再每源均摊挑 —— 若按目录名字母序挑, 会在碰到大源之前就撞上
    # 总量上限(实测 720 个全被 jianpucn-b*~j* 这些小源吃掉, 1936 个 backlog 的 jianpucn-pop 一个没进)。
    srcs = []
    for src in sorted(glob.glob(os.path.join(ROOT, "images-prep", "*"))):
        name = os.path.basename(src)
        if not os.path.isdir(src) or name.startswith("_"):
            continue
        todo = sorted(d for d in glob.glob(os.path.join(src, "*"))
                      if os.path.isdir(d) and os.path.basename(d) not in have)
        if len(todo) >= a.min_left:
            srcs.append((len(todo), name, todo))
    srcs.sort(key=lambda x: -x[0])

    picked, per = [], {}
    for _n, name, todo in srcs:
        take = [os.path.basename(d) for d in todo[:a.per_source]]
        if len(picked) + len(take) > a.max_total:
            take = take[:max(0, a.max_total - len(picked))]
        if not take:
            continue
        picked += take
        per[name] = len(take)
        if len(picked) >= a.max_total:
            break

    with io.open(a.out, "w", encoding="utf-8") as g:
        g.write("\n".join(picked) + "\n")
    print(f"挑了 {len(picked)} 个谱目录, 来自 {len(per)} 个源 -> {a.out}")
    for k, v in sorted(per.items(), key=lambda x: -x[1]):
        print(f"   {k:<24} {v}")


if __name__ == "__main__":
    main()
