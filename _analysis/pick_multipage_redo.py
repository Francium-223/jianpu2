# -*- coding: utf-8 -*-
"""挑"多页谱回锅"名单: 图库里 >=2 张竖版谱页、且**已经转录过**的目录。

为什么: 旧管线只用 pick_page 挑一张页(qupu123 还特别偏爱 002.jpg), 多页谱的成品因此是
半首甚至"和弦谱那页"。实测 `爱错（简和谱）__qupu123-350544` 旧成品只有 `1 7 - 3 6 5 1`
六个音, 换成多页拼接后 232 token / 204 数字。

排序(先转最值钱的):
  1) 曲名命中四份榜单的(直接关系头条指标);
  2) 成品音符数最少的(越短越可能是被截断的残片);
  3) 其它。
只读 + 写名单。用法: py -3.13 _analysis/pick_multipage_redo.py [--top 400]
"""
import argparse
import os
import re

ROOT = r"D:\Documents_D\jianpu2"
DB = r"D:\Documents_D\jianpu-db"
BOUT = os.path.join(ROOT, "batch-out")
OUTDIR = os.path.join(ROOT, "jianpu-db-out", "scores")
LISTS = [
    os.path.join(ROOT, "train-work", "eval_set_kugou_hualiu_2025.tsv"),
    os.path.join(ROOT, "train-work", "eval_set_cn_pop_100classics.tsv"),
    os.path.join(ROOT, "train-work", "eval_set_cma_30years30songs.tsv"),
    os.path.join(ROOT, "train-work", "eval_set_tme_2024_top10.tsv"),
]
OUT = os.path.join(ROOT, "train-work", "multipage_redo.txt")


def norm(s):
    return re.sub(r"[\s（）()【】\[\]·,，.。!！?？'\"“”‘’\-—_/\\|~～:：;；&]", "", s).lower()


def load_notes_by_source():
    """从语料里建 `源号 -> 音符个数`(成品文件名常是清理过的曲名, 不能按目录名去找)。"""
    import json
    m = {}
    p = os.path.join(DB, "data.jsonl")
    if not os.path.exists(p):
        return m
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        sc = r.get("score") or ""
        n = len(re.findall(r"[0-9]", sc))
        for s in r.get("source") or []:
            m[s] = max(m.get(s, -1), n)
        for f in r.get("file") or []:
            m["file:" + os.path.splitext(f)[0]] = n
    return m


BY_SOURCE = load_notes_by_source()


def note_count(name):
    """成品里音符数字的个数(拿不到就 -1)。"""
    src = name.split("__")[-1] if "__" in name else ""
    for key in (src, "file:" + name):
        if key and key in BY_SOURCE:
            return BY_SOURCE[key]
    for base in (OUTDIR, os.path.join(DB, "scores")):
        p = os.path.join(base, name + ".txt")
        if not os.path.exists(p):
            continue
        try:
            txt = open(p, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        body = []
        for line in txt.splitlines():
            if line.startswith("%") or "=" in line[:12]:
                continue
            body.append(line)
        return len(re.findall(r"[0-9]", " ".join(body)))
    return -1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=400)
    a = ap.parse_args()

    list_titles = set()
    for f in LISTS:
        if not os.path.exists(f):
            continue
        for line in open(f, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            t = re.split(r"\t+", line)[0]
            t = re.sub(r"[（(].*?[)）]", "", t).strip()
            if t and t != "曲名":
                list_titles.add(norm(t))

    have = {os.path.splitext(f)[0] for f in os.listdir(BOUT) if f.endswith(".txt")}
    rows = []
    for line in open(os.path.join(ROOT, "_analysis", "multipage_dirs.txt"), encoding="utf-8"):
        pages, name = line.rstrip("\n").split("\t", 1)
        if name not in have or name not in have:
            continue
        n_notes = note_count(name)
        hit = norm(re.sub(r"__.*$", "", name))
        on_list = any(t and t in hit for t in list_titles)
        rows.append((0 if on_list else 1, n_notes, name, int(pages)))

    rows.sort(key=lambda r: (r[0], r[1]))
    picked = rows[: a.top]
    with open(OUT, "w", encoding="utf-8") as f:
        for _p, _n, name, _k in picked:
            f.write(name + "\n")
    print(f"多页且已转录 {len(rows)} 个 · 本名单取 {len(picked)} 个 -> {OUT}")
    print(f"  其中命中榜单 {sum(1 for r in rows if r[0] == 0)} 个")
    print("  最值钱的前 15 个(榜单优先, 音符少的优先):")
    for p_, n_, name, k in picked[:15]:
        tag = "榜单" if p_ == 0 else "    "
        print(f"   {tag} {n_:>4} 音 {k:>2} 页  {name[:66]}")
    print(f"  音符数中位数: {sorted(r[1] for r in rows)[len(rows)//2]}")


if __name__ == "__main__":
    main()
