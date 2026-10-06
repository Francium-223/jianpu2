# -*- coding: utf-8 -*-
"""**只读普查**: `images-prep` 里的图目录 vs 语料的账 —— 回答"到底还能涨多少首"。

为什么要它(实测 2026-10-05): 转写队列一轮 3412 条净增 +1、一轮 1764 条净增 0,
"每轮处理一两千条、净增收成 0~1" 说明队列里绝大多数是**语料里早就有的东西**。
要修这件事, 先得把账点清: 图目录里有几个是"真新曲"(source 与曲名都不在语料)。

本工具**只读**: 不写语料、不写图库、不转写。唯一的写动作是 `--out` 落一份普查 TSV。

口径(三处判据各是谁, 别混):
  * `source` 命中 —— `scores/*.txt` 里的 `source=站-id`, 读法照抄 `tools/corpus_index.py`;
  * `曲名` 命中(严) —— `norm(曲名) == norm(语料 title)`, 这是 `tools/queue_from_crawl.py`
    **现行**的判据(`norm(title) in corpus_titles(data.jsonl)`), 相等才算, 不做包含;
  * `曲名` 命中(松) —— `tools/corpus_index.py: title_in_corpus()`, 照抄
    `skills/jianpu-melody-lookup/eval_golden.py: same()` 的包含规则(被含一方 >=4 字且占长串一半以上)。
真新曲数给**两个值**: 按严口径(现状队列用的)与按松口径(corpus_index 用的), 差额就是
"队列判据比语料索引松"放过去的那一批。

曲名解析照抄 `tools/queue_from_crawl.py: parse_dir()`(`__站-id` 后缀 + 砍 `_(` 之后的歌手续尾
+ 砍 `简谱/吉他谱/...` 结尾), 因为**队列就是这么看目录名的**, 用别的解析算出来的数对不上队列。

"可用图片"= 该目录**一层内**(不递归, 与 `queue_from_crawl` 的 `glob(d/*)` 同形)扩展名匹配
且**字节数 > 0** 的图。0 字节的图在转写时必然出空产物, 算不可用。

用法:
    python3 tools/census_images_prep.py                 # 打摘要
    python3 tools/census_images_prep.py --out train-work/census_images_prep.tsv
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

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

if HERE not in sys.path:
    sys.path.insert(0, HERE)
from jp_root import images_root                                     # noqa: E402
import corpus_index                                                 # noqa: E402
from queue_from_crawl import parse_dir, SITES                        # noqa: E402  同一份目录名解析 + 站点表

IMG = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)
# 目录名后缀 `__站-id`: 站点名允许字母数字(corpus_index 同口径), id 允许字母下划线
# (to_jianpu_db.py 的拼音别名页就是 `__xxx-ab12` 这种)。
DIRSID = re.compile(r"__([a-z0-9]+)-([0-9a-z_]+)$")
# 站点表**不在本文件里另立一份**: 直接复用 `queue_from_crawl.SITES`(读 `tools/sources.json`)。
# 早先这里写死 `("qupu123", "jianpucn", "jianpujia")`, 于是 jp114 在普查里被归成"其他"
# (队列侧更狠: 直接扫不到) —— 同一份白名单有两个真源, 迟早对不上。


def site_group(site):
    return site if site in SITES else "其他"


def corpus_titles_strict(db):
    """**现行队列**的曲名口径: `data.jsonl` 的 title, 过 `eval_golden.norm`, 只认相等。

    为什么读 data.jsonl 而不是 scores/: 因为 `queue_from_crawl.py` 读的就是它,
    要复现队列数就得跟它同一份账。读不动(文件不在/损坏)时返回空集并**明说**,
    不要静默当成"语料是空的"(那样真新曲数会虚高)。
    """
    p = os.path.join(db, "data.jsonl")
    try:
        f = io.open(p, encoding="utf-8", errors="replace")
    except OSError:
        print("[census] ⚠ data.jsonl 读不到, 曲名严口径退化为空集 → 真新曲数会偏高: %s" % p,
              file=sys.stderr)
        return set()
    out = set()
    with f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                r = json.loads(ln)
            except ValueError:
                continue
            t = r.get("title")
            if t:
                out.add(norm_title_cf(t))
    out.discard("")
    return out


def norm_title_cf(s):
    """`eval_golden.norm` 的薄封装 —— 拿不到就用 corpus_index 的同口径实现。"""
    try:
        sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
        from eval_golden import norm as _n
        return _n(s)
    except Exception:
        return corpus_index.norm_title(s)


def walk_song_dirs(root):
    """递归找出所有 `曲名__站-id` 图目录。返回 [(dirname, dirpath, depth)]。

    ⚠ 队列(`queue_from_crawl.py`)只扫 **一层**(`<images>/<分类>/<曲名__站-id>`),
    本普查**递归**扫, 这样能看出"还有多少目录队列根本看不见" —— 这个差额本身是个结论。
    """
    out = []
    root = os.path.abspath(root)
    for dirpath, dirnames, _files in os.walk(root):
        for d in list(dirnames):
            if DIRSID.search(d):
                depth = os.path.relpath(os.path.join(dirpath, d), root).count(os.sep)
                out.append((d, os.path.join(dirpath, d), depth))
    return out


def usable_images(d):
    """目录一层内的可用图(扩展名匹配 + 字节 > 0)。"""
    try:
        names = os.listdir(d)
    except OSError:
        return []
    out = []
    for n in names:
        if not IMG.search(n):
            continue
        p = os.path.join(d, n)
        try:
            if os.path.isfile(p) and os.path.getsize(p) > 0:
                out.append(p)
        except OSError:
            pass
    return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", default=images_root(), help="图库根(默认 images_root())")
    ap.add_argument("--db", default=corpus_index.db_root(), help="jianpu-db 根")
    ap.add_argument("--out", default="", help="落一份普查 TSV(唯一写动作; 不填就纯打印)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    root = a.images
    if not os.path.isdir(root):
        print("图库根不存在: %s" % root)
        return 1

    srcs = corpus_index.existing_sources()
    strict = corpus_titles_strict(a.db)
    print("图库根 %s" % root)
    print("语料 source %d 个 · 语料曲名(严口径, data.jsonl) %d 个 · 语料曲名(松口径) %d 个"
          % (len(srcs), len(strict), len(corpus_index.existing_score_names())))

    dirs = walk_song_dirs(root)
    hist = collections.Counter(d for _n, _p, d in dirs)
    print("`曲名__站-id` 图目录 %d 个 · 层级分布 %s"
          % (len(dirs), ", ".join("第%d层 %d" % (k, hist[k]) for k in sorted(hist))))

    rows = []
    stat = collections.Counter()
    per_site = collections.defaultdict(collections.Counter)
    pages_new = collections.Counter()
    for name, path, depth in dirs:
        got = parse_dir(name)
        if got:
            title, site, sid = got
        else:
            m = DIRSID.search(name)
            site, sid = m.group(1), m.group(2)
            title = name[:m.start()]
        key = "%s-%s" % (site, sid)
        src_hit = key in srcs
        # 严: 队列现行判据。松: corpus_index 的包含判据。
        t_strict = norm_title_cf(title) in strict
        t_loose = corpus_index.title_in_corpus(name) or corpus_index.title_in_corpus(title)
        imgs = usable_images(path)
        n = len(imgs)
        if src_hit:
            verdict = "已在语料-source"
        elif t_strict or t_loose:
            verdict = "已在语料-曲名"
        else:
            verdict = "真新曲"
        stat[verdict] += 1
        per_site[site][verdict] += 1
        if verdict == "真新曲":
            pages_new["无可用图片" if n == 0 else ("单页" if n == 1 else "多页")] += 1
        rows.append((verdict, name, title, site, sid, str(n), str(depth),
                     "1" if src_hit else "0", "1" if t_strict else "0", "1" if t_loose else "0"))

    total = len(dirs)
    def pct(k):
        return "%d (%.1f%%)" % (stat[k], 100.0 * stat[k] / total) if total else "0"

    print("\n== 一、总账 ==")
    print("  已在语料(source命中)      %s" % pct("已在语料-source"))
    print("  曲名已在语料 source不在   %s" % pct("已在语料-曲名"))
    print("  **真新曲(source与曲名都不在)** %s" % pct("真新曲"))

    print("\n== 二、真新曲的页数 ==")
    for k in ("多页", "单页", "无可用图片"):
        print("  %-8s %d" % (k, pages_new[k]))
    usable = pages_new["多页"] + pages_new["单页"]
    print("  可转写(有图) %d" % usable)

    print("\n== 三、按站点 ==")
    for site in sorted(per_site, key=lambda s: -sum(per_site[s].values())):
        c = per_site[site]
        print("  %-12s 总 %5d · source %5d · 曲名 %5d · 真新曲 %5d"
              % (site, sum(c.values()), c["已在语料-source"], c["已在语料-曲名"], c["真新曲"]))

    print("\n== 四、按站点分组的真新曲页数 ==")
    site_pages = collections.defaultdict(collections.Counter)
    for verdict, name, title, site, sid, n, depth, sh, ts, tl in rows:
        if verdict != "真新曲":
            continue
        ni = int(n)
        site_pages[site]["无可用图片" if ni == 0 else ("单页" if ni == 1 else "多页")] += 1
    for site in sorted(site_pages, key=lambda s: -sum(site_pages[s].values())):
        c = site_pages[site]
        print("  %-12s 多页 %4d · 单页 %4d · 无图 %4d" % (site, c["多页"], c["单页"], c["无可用图片"]))

    if a.out:
        d = os.path.dirname(os.path.abspath(a.out))
        if d:
            os.makedirs(d, exist_ok=True)
        with io.open(a.out, "w", encoding="utf-8", newline="\n") as f:
            f.write("判定\t目录名\t曲名\t站点\t站内id\t可用图数\t层级\tsource命中\t曲名严命中\t曲名松命中\n")
            for r in sorted(rows):
                f.write("\t".join(r) + "\n")
        print("\n明细 ->", a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
