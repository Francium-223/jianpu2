# -*- coding: utf-8 -*-
"""把**爬回来的图**分拣成一份"可转写队列" —— 排除库里已有的、按曲名去重、标出器乐改编。

为什么要它: 爬虫(`crawl_batch_jianpujia.py`)只管下载, 一晚上下来几千个目录; 得有人回答
"这里面有多少是**新歌**、多少只是库里已有的重复、多少是器乐改编(按项目口径不收)"。
`verify_crawl_matches.py` 是**拿着清单找图**(目标 -> 页), 这个是**拿着图找新歌**(页 -> 目标),
方向相反, 所以单列一个工具, 但**口径全部复用**: 同一个 `ARRANGE` 正则 + `eval_golden.norm/same`。

用法:
    python3 tools/queue_from_crawl.py                          # 扫工作区 images-prep, 出摘要
    python3 tools/queue_from_crawl.py --out _analysis/队列.tsv  # 落 TSV
    python3 tools/queue_from_crawl.py --dirs images-prep/jianpujia-1252 ...   # 只扫指定目录
"""
import argparse
import collections
import glob
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)                         # 工作区
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
from verify_crawl_matches import ARRANGE          # noqa: E402  同一份"改编"口径
from eval_golden import norm                      # noqa: E402  同一份曲名口径

IMG = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)
SID = re.compile(r"^(.*?)__(jianpujia|qupu123|jianpucn)-(\d+)$")


def corpus_titles(db):
    out = set()
    with open(os.path.join(db, "data.jsonl"), encoding="utf-8") as f:
        for ln in f:
            r = json.loads(ln)
            if r.get("title"):
                out.add(norm(r["title"]))
    out.discard("")
    return out


def parse_dir(name):
    """目录名 -> (标题, 站, id)。目录名形如 `曲名简谱(歌词)_歌手_记谱__jianpujia-9998`。"""
    m = SID.match(name)
    if not m:
        return None
    title = m.group(1)
    title = re.split(r"[_（(]", title)[0]
    title = re.sub(r"(简谱|钢琴谱|吉他谱|古筝谱|五线谱|指弹谱|弹唱谱|总谱|正谱)$", "", title).strip()
    return (title, m.group(2), m.group(3))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=os.path.join(WS, "jianpu-db"))
    ap.add_argument("--images", default=os.path.join(WS, "images-prep"))
    ap.add_argument("--dirs", nargs="*", default=[], help="只扫这些分类目录(默认扫 --images 下全部)")
    ap.add_argument("--out", default="", help="TSV 输出路径(默认只打摘要)")
    ap.add_argument("--with-images", action="store_true",
                    help="额外出一列**图路径**(给转写队列用: 一个可以直接喂给 transcribe.py 的清单)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    have = corpus_titles(a.db)
    roots = a.dirs or sorted(glob.glob(os.path.join(a.images, "*")))
    rows, seen_title = [], set()
    stat = collections.Counter()
    for root in roots:
        for d in sorted(glob.glob(os.path.join(root, "*"))):
            if not os.path.isdir(d):
                continue
            got = parse_dir(os.path.basename(d))
            if not got:
                continue
            title, site, sid = got
            n = len([x for x in glob.glob(os.path.join(d, "*")) if IMG.search(x)])
            if n == 0:
                continue
            dup = norm(title) in have
            arr = bool(ARRANGE.search(os.path.basename(d)))
            stat["目录"] += 1
            if dup:
                stat["库里已有"] += 1
                continue
            if arr:
                stat["改编(不收)"] += 1
            if norm(title) in seen_title:
                stat["重复曲名"] += 1
                continue
            seen_title.add(norm(title))
            first = ""
            if a.with_images:
                imgs = sorted(x for x in glob.glob(os.path.join(d, "*")) if IMG.search(x))
                first = imgs[0] if imgs else ""
            rows.append((title, site, sid, str(n), "改编" if arr else "简谱", os.path.basename(d), first))
            stat["新歌(去重)"] += 1
            if not arr:
                stat["可转写(非改编)"] += 1

    print(f"扫描 {len(roots)} 个来源目录 · 语料 {len(have)} 个曲名")
    for k in ("目录", "库里已有", "改编(不收)", "重复曲名", "新歌(去重)", "可转写(非改编)"):
        print(f"  {k:<14} {stat[k]}")
    if a.out:
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        with io.open(a.out, "w", encoding="utf-8", newline="\n") as f:
            cols = "曲名\t站\t页面id\t页数\t类型\t目录" + ("\t首图\n" if a.with_images else "\n")
            f.write(cols)
            for r in sorted(rows):
                f.write("\t".join(r) + "\n")
        print("明细 ->", a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
