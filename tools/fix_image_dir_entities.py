#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把图库目录名里的 HTML 实体去掉（`&nbsp;` 等）。

为什么: `crawl_jianpucn_by_title.py` 早期版本直接把站点标题当初目录名，于是出现
`阿姐鼓&nbsp;&nbsp;__jianpucn-123733` 这种目录。目录名会被 `queue_from_crawl.py` 解析成
转写队列的**"曲名"列**，转写完就变成 `title=阿姐鼓&nbsp;&nbsp;` —— 实体一路漏进语料。

（爬虫本身已修：`safe()` 里先 `ENT.sub("", s)`。这个工具负责把**已经下下来的**目录改名。）

用法:
    python3 tools/fix_image_dir_entities.py --plan     # 只打印计划
    python3 tools/fix_image_dir_entities.py --apply    # 改名
"""
import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # jianpu2/
WS = os.path.dirname(ROOT)                        # 工作区
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or os.path.join(WS, "images-prep")

ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")


def tidy(name):
    """去实体 + 收拾残留空格。没有实体则返回 ''(表示这条不用动)。"""
    if not ENT.search(name):
        return ""
    new = ENT.sub("", name)
    new = re.sub(r"[ \u3000]+__", "__", new)       # 实体在 `__站点-id` 前面时留下的空格
    new = re.sub(r"\s{2,}", " ", new).strip()
    return new if new and new != name else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", default=IMG_ROOT)
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    if not (a.plan or a.apply):
        print("要先说清楚干什么: 加 --plan 看计划, 或 --apply 落地")
        return 2

    plans = []
    for top in sorted(os.listdir(a.images)):
        tp = os.path.join(a.images, top)
        if not os.path.isdir(tp):
            continue
        taken = set(os.listdir(tp))
        for d in sorted(os.listdir(tp)):
            new = tidy(d)
            if not new:
                continue
            tgt = new
            i = 2
            while tgt in taken and tgt != d:       # 撞名就加 _2/_3…
                base, ext = os.path.splitext(new)
                tgt = "%s_%d%s" % (base, i, ext)
                i += 1
            taken.add(tgt)
            plans.append((os.path.join(tp, d), os.path.join(tp, tgt), top, d, tgt))

    print("含 HTML 实体的目录: %d 个 (图库 %s)" % (len(plans), a.images))
    for src, dst, top, old, new in plans[:20]:
        print("   [%s] %s\n        -> %s" % (top, old, new))
    if len(plans) > 20:
        print("   ... 还有 %d 个" % (len(plans) - 20))

    if not a.apply:
        print("\n(只打印, 没动任何目录; 落地请加 --apply)")
        return 0

    n = 0
    for src, dst, *_ in plans:
        if os.path.exists(dst):
            print("   跳过(目标已存在): %s" % dst)
            continue
        os.rename(src, dst)
        n += 1
    print("\n已改名 %d 个目录" % n)
    print("注意: 队列文件里记的是**旧路径**, 重新跑一遍即可:")
    print("  python3 tools/queue_from_crawl.py --with-images --out <队列>.tsv")
    return 0


if __name__ == "__main__":
    if any(x in ("-h", "--help") for x in sys.argv[1:]):
        print(__doc__)
        raise SystemExit(0)
    sys.exit(main())
