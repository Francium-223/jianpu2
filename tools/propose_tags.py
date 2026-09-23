#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给「还没打标签」的曲**提议**分类标签, 并可选落盘。

为什么能做: 原谱站自己就带分类, 而语料里**已经打好标签的那批**告诉我们站点分类怎么映射到
本仓库的标签词表 —— 映射表是从既有数据里反推的(见下表"命中率"), 不是拍脑袋定的。

站点信号:
  * qupu123   URL 第一段就是流派(tongsu/minge/shaoer/hechang/jipu/puyou/meisheng/waiguo/yuanchuang/xiqu/qiyue)
  * jianpujia URL 只有 `jianpu` 一段 -> 分类在页面里(需联网取一次; 本脚本默认只处理已有的)
  * jianpucn  面包屑只给"三字歌谱"这种**字数**分类, 没有流派 -> 不给分类标签(只留歌手线索)

映射表(命中率 = 该流派段里已经用了这个标签的曲 / 该段已打标签的曲):
  tongsu   -> 分类/通俗歌曲  76%      minge    -> 分类/民歌      93%
  shaoer   -> 分类/儿歌      96%      hechang  -> 分类/合唱      93%
  puyou    -> 分类/谱友上传  76%      meisheng -> 分类/美声      87%
  xiqu     -> 分类/戏曲     100%(1 首)
  **置信度不足、默认不自动落盘**(只列进提案): jipu 48% / waiguo 41% / yuanchuang 23% / qiyue 50%

用法:
  python3 jianpu2/tools/propose_tags.py                    # 只出提案 _analysis/tag_proposal.tsv
  python3 jianpu2/tools/propose_tags.py --apply            # 高置信度的写进 scores/*.txt
  python3 jianpu2/tools/propose_tags.py --apply --also-weak
"""
import argparse
import collections
import json
import os
import re
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2/
WS = os.path.dirname(ROOT)                         # 语料根
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
sys.stdout.reconfigure(encoding="utf-8")

# 站点流派段 -> 本仓库标签(括号里是从既有数据量出来的命中率)
SECTION_TAG = {
    "tongsu": ("分类/通俗歌曲", 0.76),
    "minge": ("分类/民歌", 0.93),
    "shaoer": ("分类/儿歌", 0.96),
    "hechang": ("分类/合唱", 0.93),
    "puyou": ("分类/谱友上传", 0.76),
    "meisheng": ("分类/美声", 0.87),
    "xiqu": ("分类/戏曲", 1.00),
}
WEAK = {"jipu": "分类/记谱", "waiguo": "分类/外国歌曲",
        "yuanchuang": "分类/原创", "qiyue": "分类/器乐"}
CONF_MIN = 0.60                                    # 只有命中率 >=0.6 的才自动落盘


def load_sources():
    p = os.path.join(DB, "source_pages.json")
    return json.load(open(p, encoding="utf-8")) if os.path.isfile(p) else {}


def section_of(url):
    return urllib.parse.urlsplit(url).path.strip("/").split("/")[0]


def read_head(path):
    t = open(path, encoding="utf-8", errors="replace").read()
    return t, (t.split("%--", 1)[0] if "%--" in t else t)


def add_tag(path, tag):
    """把 usertag 加进曲谱的元数据区; 并在打上标签后去掉 `todo=add tags`。
    返回 'added' / 'exists'。行尾保持原样。

    插入位置: 第一条 `%--` 之前; 若整份谱没有 `%--`, 就插在**元数据区末尾**
    (最后一行的 `%注释` 或 `key=value` 之后), 绝不插到曲谱正文/文件末尾。
    """
    raw = open(path, "rb").read()
    nl = "\r\n" if b"\r\n" in raw else "\n"
    lines = raw.decode("utf-8").splitlines()
    end = next((i for i, l in enumerate(lines) if l.replace(" ", "").startswith("%--")), None)
    if end is None:
        end = 0
        for i, l in enumerate(lines):
            s = l.strip()
            if not s or s.startswith("%") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", s):
                end = i + 1
            else:
                break
    ui = next((i for i in range(end) if lines[i].startswith("usertag=")), None)
    have = ([x.strip() for x in lines[ui][8:].split(",") if x.strip()] if ui is not None else [])
    if tag in have:
        return "exists"
    if ui is None:
        lines.insert(end, "usertag=" + tag)
    else:
        lines[ui] = "usertag=" + ",".join(have + [tag])
    # 打完标签就把 todo=add tags 去掉(这条 todo 的字面意思就是"该加标签了")
    lines = [l for l in lines if l.strip() != "todo=add tags"]
    open(path, "wb").write((nl.join(lines) + nl).encode("utf-8"))
    return "added"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="真的写进 scores/*.txt")
    ap.add_argument("--also-weak", action="store_true", help="连低置信度的也一起写")
    ap.add_argument("--out", default=os.path.join(WS, "_analysis", "tag_proposal.tsv"))
    a = ap.parse_args()

    sp = load_sources()
    rows, stats = [], collections.Counter()
    files = sorted(f for f in os.listdir(SCORES)
                   if f.endswith(".txt") and not f.endswith(("_expand.txt", "_buf.txt")))
    for fn in files:
        path = os.path.join(SCORES, fn)
        txt, head = read_head(path)
        ut = re.search(r"(?m)^usertag=(.*)$", head)
        if ut and ut.group(1).strip():
            continue                                   # 已经有标签, 不动
        if "todo=add tags" not in head and not (ut is None):
            continue
        src = re.search(r"(?m)^source=(\S+)", head)
        src = src.group(1) if src else ""
        title = re.search(r"(?m)^title=(.*)$", head)
        title = title.group(1).strip() if title else fn
        url = (sp.get(src) or {}).get("url", "")
        site = src.split("-")[0] if src else ""
        tag, conf, why = "", 0.0, ""
        if site == "qupu123" and url:
            seg = section_of(url)
            if seg in SECTION_TAG:
                tag, conf, why = SECTION_TAG[seg][0], SECTION_TAG[seg][1], "qupu123 栏目 %s(%s)" % (seg, url)
            elif seg in WEAK:
                tag, conf, why = WEAK[seg], 0.0, "qupu123 栏目 %s(置信度不足)" % seg
        elif site == "jianpujia":
            why = "jianpujia 页面分类需联网取(见 --fetch-jianpujia)"
        else:
            why = "%s 站点没有流派分类(只有字数分类)" % (site or "无 source")
        rows.append((fn, title, src, tag, conf, why))
        stats[(site, tag or "(未提议)")] += 1

    with open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("file\ttitle\tsource\tproposed_tag\tconf\tevidence\n")
        for r in rows:
            g.write("\t".join(str(x) for x in r) + "\n")
    print("提案写出: %s (%d 条)" % (a.out, len(rows)))
    print()
    print("按站点/提议汇总:")
    for (site, tag), n in sorted(stats.items(), key=lambda x: -x[1]):
        print("   %-12s %-16s %d" % (site, tag, n))

    strong = [r for r in rows if r[3] and r[4] >= CONF_MIN]
    weak = [r for r in rows if r[3] and r[4] < CONF_MIN]
    print()
    print("高置信度可落盘: %d 条;  低置信度(仅提案): %d 条;  无法提议: %d 条"
          % (len(strong), len(weak), len(rows) - len(strong) - len(weak)))
    if not a.apply:
        print("\n(--apply 才会真的写进 scores/*.txt; 现在只是提案)")
        return 0
    todo = strong + (weak if a.also_weak else [])
    n_add = n_ex = 0
    for fn, *_ in todo:
        try:
            r = add_tag(os.path.join(SCORES, fn), [x for x in rows if x[0] == fn][0][3])
            n_add += r == "added"
            n_ex += r == "exists"
        except Exception as e:
            print("  ! %s: %s" % (fn, e))
    print("已写入 %d 首(已存在 %d 首)。记得跑 parse_scores.py 重建索引。" % (n_add, n_ex))
    return 0


if __name__ == "__main__":
    sys.exit(main())
