# -*- coding: utf-8 -*-
"""把**歌手**变成独立字段 `artist=`，并给"同名不同曲"的文件名做消歧。

用户口径（2026-09-24）：歌手不该只混在 `usertag` 里 ——
* 通用曲名（《海阔天空》《爱》《家》）现在靠 `_2`/`_3` 这种无信息后缀区分 ✗；
* 应该：`artist=歌手名`（独立字段，能进 data.jsonl / 网页 / HF），**文件名也带上歌手**。

歌手从哪来（**有证据**）：`train-work/artist_cache/artists.json` —— `harvest_artists.py`
从原谱站**页面标题**里抽出来的，按 `source`（站点-站内id）缓存。所以这里按 source 匹配，
**不靠曲名猜**，也不怕以后文件被改名。

用法:
    python3 tools/set_artists.py                 # 只报计划（默认 dry）
    python3 tools/set_artists.py --apply         # 写 artist=（只补缺失的，已有的不动）
    python3 tools/set_artists.py --apply --rename  # 顺带把撞名文件改成 `曲名（歌手）.txt`

注意：`refine_titles_from_pages.py --apply` 之后文件名可能被它按"纯曲名"重写（丢掉歌手），
      所以**改完曲名再跑一次本脚本的 --rename** 即可恢复。
"""
import argparse
import collections
import csv
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
CACHE = os.path.join(ROOT, "train-work", "artist_cache", "artists.json")
COLLISIONS = os.path.join(WS, "_analysis", "同名不同曲提案.tsv")
sys.path.insert(0, DB)


def head_of(path):
    return io.open(path, encoding="utf-8", errors="replace").read().split("%--", 1)[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--rename", action="store_true", help="同时给撞名文件改名(曲名（歌手）.txt)")
    ap.add_argument("--show", type=int, default=10)
    a = ap.parse_args()

    if not os.path.isfile(CACHE):
        sys.exit(f"没有歌手缓存: {CACHE}")
    cache = json.load(io.open(CACHE, encoding="utf-8"))
    # source -> 歌手（大小写取"多数派"写法，避免 Beyond/BEYOND 这种）
    raw = {}
    for src, rec in cache.items():
        art = (rec.get("artist") or "").strip()
        if art:
            raw[src] = art
    canon = {}
    for src, art in raw.items():
        for one in re.split(r"[,，、|]", art):
            one = one.strip()
            if one:
                canon.setdefault(one.casefold(), collections.Counter())[one] += 1
    majority = {k: v.most_common(1)[0][0] for k, v in canon.items()}

    # 页面标题里抽出来的"歌手"会混进**版本描述**(实测: "双吉他版"、"吉他 — Beyond"、
    # "电子琴伴奏配器 邓丽君"、"怀旧经典 邓丽君")。写进 `artist=` 之前必须过滤,
    # 否则字段就成了垃圾场 ✗。规则: 含版本/乐器/谱类关键词 -> 不算人名;
    # 但若这一串里**含有**一个已知歌手名, 就取那个(如 "怀旧经典 邓丽君" -> 邓丽君)。
    NOISE = re.compile(r"版|谱|伴奏|配器|吉他|钢琴|电子琴|古筝|竹笛|口琴|二胡|合唱|独唱|弹唱|"
                       r"重奏|协奏|乐队|总谱|正谱|编配|指弹|卡林巴|五线谱|简和谱|考级|"
                       r"经典|怀旧|原唱|翻唱|纯音乐|演奏|示范|教学|视频|动态谱|手稿|记谱")
    known = {k: v for k, v in majority.items() if len(v) <= 12 and not NOISE.search(v)}

    def pick_one(token):
        t = token.strip()
        if not t:
            return ""
        if not NOISE.search(t) and len(t) <= 12:
            return majority.get(t.casefold(), t)
        for k, v in known.items():                    # 整串里含已知歌手 -> 取它
            if k and k in t.casefold():
                return v
        return ""

    def clean(art):
        parts = [pick_one(x) for x in re.split(r"[,，、|]", art)]
        return ",".join(dict.fromkeys([p for p in parts if p]))

    # 遍历语料
    todo_add, already, no_artist = [], 0, 0
    src_of = {}
    for fn in sorted(os.listdir(SCORES)):
        if not fn.endswith(".txt") or fn.endswith(("_expand.txt", "_buf.txt")):
            continue
        head = head_of(os.path.join(SCORES, fn))
        m = re.search(r"(?m)^source=(\S+)", head)
        src = m.group(1) if m else ""
        src_of[fn] = src
        if not src or src not in raw:
            no_artist += 1
            continue
        cur = re.search(r"(?m)^artist=(.*)$", head)
        if cur and cur.group(1).strip():
            already += 1
            continue
        c = clean(raw[src])
        if not c:                       # 过滤后为空(整串都是版本描述) -> 不写, 也别让它进清单
            no_artist += 1
            continue
        todo_add.append((fn, c))

    print(f"语料 {len(src_of)} 份谱")
    print(f"  缓存里有歌手、且曲谱还没写 artist= 的: {len(todo_add)} 份  -> 会写 `artist=`")
    print(f"  已经有 artist= 的: {already}")
    print(f"  缓存里没有歌手的: {no_artist}")
    dropped = sum(1 for _s, art in raw.items() if not clean(art))
    print(f"  缓存里有值但**过滤后不像人名**的(不写): {dropped}")

    # 撞名组
    renames = []
    unresolved = []
    if os.path.isfile(COLLISIONS):
        groups = {}
        for ln in io.open(COLLISIONS, encoding="utf-8"):
            c = ln.rstrip("\n").split("\t")
            if len(c) < 6 or c[0] == "曲名组":
                continue
            groups[c[0]] = [f for f in c[5].split(" | ") if f]
        for title, files in groups.items():
            arts = {f: raw.get(src_of.get(f, ""), "") for f in files}
            # ⚠ 过滤后可能为空(整串都是"双吉他版"这种版本描述) -> 必须剔除,
            # 否则会生成 `曲名（）.txt` 这种空括号(实测踩过)
            known = {f: c for f, c in ((f, clean(v)) for f, v in arts.items()) if c}
            if len(known) < 2:
                unresolved.append((title, files, known))
                continue
            used = collections.Counter()
            for f, art in known.items():
                if not os.path.isfile(os.path.join(SCORES, f)):
                    continue
                base = re.sub(r'[\\/:*?"<>|\x00-\x1f]', "_", f"{title}（{art}）").strip()[:110]
                used[base] += 1
                # 同一组里两首都归到同一个歌手(多半是同一首的重复转写) -> 加 _2/_3 保证唯一
                suffix = "" if used[base] == 1 else f"_{used[base]}"
                newname = base + suffix + ".txt"
                if newname != f:
                    renames.append((f, newname, art))
        print(f"\n同名不同曲组 {len(groups)} 个:")
        print(f"  能给文件名消歧的成员文件: {len(renames)}")
        print(f"  两组歌手都不全、暂时改不了的组: {len(unresolved)}")
        for f, n, art in renames[:a.show]:
            print(f"    {f[:40]:42s} -> {n[:44]}")

    if not a.apply:
        print("\n(--apply 才真的写; --apply --rename 才会改名)")
        return 0

    from linkurl import add_field
    ok = upd = 0
    for fn, art in todo_add:
        if not art:
            continue
        r = add_field(os.path.join(SCORES, fn), "artist", art)
        ok += (r == "added")
        upd += (r == "updated")
    print(f"\n写入 artist=: 新增 {ok}, 更新 {upd}")

    if a.rename:
        moved = 0
        for f, n, _art in renames:
            old, new = os.path.join(SCORES, f), os.path.join(SCORES, n)
            if os.path.exists(new):
                print(f"  ! 目标已存在, 跳过: {n}")
                continue
            raw_txt = io.open(old, encoding="utf-8").read()
            # 第一行是 `%<文件名>` 的约定 -> 改名后同步(parse() 时也会自己修好, 但这里显式改掉)
            lines = raw_txt.splitlines()
            if lines and lines[0].startswith("%"):
                lines[0] = "%" + n
                raw_txt = "\n".join(lines) + ("\n" if raw_txt.endswith("\n") else "")
            io.open(old, "w", encoding="utf-8", newline="").write(raw_txt)
            os.rename(old, new)
            moved += 1
        print(f"改名: {moved} 个文件 -> `曲名（歌手）.txt`")
    print("记得跑 parse_scores.py 重建索引（或等 refresh）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
