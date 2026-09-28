# -*- coding: utf-8 -*-
"""榜单里没命中的, 到底是"库里没有这首歌"还是"库里有但没检索到"? —— 只读诊断。

为什么要分开: 这两件事的**下一步完全不同**。
  * 库里没有 -> 天花板问题, 得去爬/转写(扩大语料);
  * 库里有、却没被检索到 -> 算法/片段问题(换更长的片段、调代价模型、看是不是被同名版本压住)。
混在一起报一个"准确率 xx%", 看不出该往哪儿使劲。

口径与 `skills/jianpu-melody-lookup/eval_golden.py` 完全一致(同一份 `norm` / `same`),
所以"库里有"这一列就是 eval_golden 判定命中时用的同一把尺。

用法:
    py -3.13 tools/diagnose_list_coverage.py --list train-work/eval_set_kugou_hualiu_2025.tsv
    py -3.13 tools/diagnose_list_coverage.py --all      # 四份榜单一起
"""
import argparse
import glob
import io
import json
import os
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
from eval_golden import norm, same        # noqa: E402  曲名口径复用同一份
from lookup import group_of               # noqa: E402

LISTS = ["eval_set_kugou_hualiu_2025.tsv", "eval_set_cn_pop_100classics.tsv",
         "eval_set_cma_30years30songs.tsv", "eval_set_tme_2024_top10.tsv"]


def read_list(path):
    """-> [(曲名, 演唱者)]; 跳过 # 注释行。

    ⚠ 四份名单的列**不统一**(实测): 酷狗/中文流行 是 `名次 曲名 演唱者 [年份]`,
    而金曲奖/腾讯 是 `曲名 演唱者 年份`(没有名次)。所以第一列是纯数字时才当名次,
    否则它就是曲名 —— 按固定列位读会把"罗文(1979)"当成曲名(实测错过 28/30 首)。
    """
    out = []
    for ln in io.open(path, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        c = [x.strip() for x in ln.split("\t")]
        off = 1 if (c and c[0].isdigit()) else 0
        if len(c) > off + 1 and c[off]:
            out.append((c[off], c[off + 1]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--list", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--outdir", default=r"D:\Documents_D\_analysis")
    a = ap.parse_args()
    if not a.list and not a.all:
        sys.exit("给 --list 或 --all(用法见 docstring)")

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    from lookup import pitch_and_oct              # noqa: E402  与检索同一口径(算"够不够 11 音")
    titles = []
    for r in rows:
        p, _o = pitch_and_oct(r.get("score") or "")
        titles.append((norm(group_of(r.get("title") or "")), (r.get("title") or ""),
                       (r.get("file") or [""])[0], len(p)))
    print(f"语料 {len(rows)} 首 -> 曲名口径索引 {len(titles)} 条")

    names = LISTS if a.all else [os.path.basename(a.list)]
    for name in names:
        path = a.list if (not a.all and a.list) else os.path.join(ROOT, "train-work", name)
        if not os.path.isfile(path):
            print(f"!! 找不到 {path}")
            continue
        items = read_list(path)
        have, short, miss = [], [], []
        for t, artist in items:
            n = norm(t)
            m = next(((orig, f, ln) for cn, orig, f, ln in titles if same(n, cn)), None)
            if m is None:
                miss.append((t, artist, None, path))
            elif m[2] < 11:
                # 曲名对得上, 但这份谱短于检索下限 11 音 -> eval_golden 的 idx 里没有它,
                # 所以它的"分母"少一个(实测酷狗 65 vs 64 就差在这里)。分出来才不冤枉算法。
                short.append((t, artist, m[0], path))
            else:
                have.append((t, artist, m[0], path))
        print()
        print(f"### {name}: 榜上 {len(items)} 首 · 库里**有可用谱** {len(have)} 首"
              f" · 有谱但**短于 11 音** {len(short)} 首 · 库里**没有** {len(miss)} 首")
        if short:
            print("    短谱(检索下限 11 音, 所以不参与分母): "
                  + "、".join(f"{t}({ar})" for t, ar, _h, _p in short[:10]))
        if miss:
            outp = os.path.join(a.outdir, "榜单缺口_" + os.path.splitext(name)[0] + ".tsv")
            with io.open(outp, "w", encoding="utf-8") as g:
                g.write("曲名\t演唱者\t榜单位置\t来源名单\n")
                for i, (t, artist, _h, p) in enumerate(miss, 1):
                    g.write(f"{t}\t{artist}\t{i}\t{os.path.basename(p)}\n")
            print(f"    缺口清单 -> {outp}")
            print("    前 10 个缺口: " + "、".join(f"{t}({ar})" if ar else t for t, ar, _h, _p in miss[:10]))


if __name__ == "__main__":
    main()
