# -*- coding: utf-8 -*-
"""逐条列出"榜上有、库里也有, 但**没命中**"的查询 —— 只读诊断。

为什么单独做: `eval_golden.py` 只打一个汇总百分比, 看不见"是谁没中、输给了谁"。
漏掉的那些才是能改的东西:
  * 正确歌在第 2、3 名 -> 片段不够独特(换更长/更靠中间的那句就中);
  * 正确歌压根不在前 5 -> 要么这首的谱转错了(旋律不对), 要么查询片段正好选自错误段落;
  * 榜首是**同名不同歌** -> 语料里的同名冲突(按曲名判定仍算命中, 但这件事本身可疑)。

排序口径与 `eval_golden.py` **逐字一致**(同一套滑窗 Hamming 距离 + 同一条 `same`/`norm` 曲名尺),
所以这里列出来的漏报就是头条指标里那些漏报。

⚠ 为什么不直接调 `lookup.py`(产品路径): 它每跑一次都要过自检门(对整个语料扫一遍),
实测 **~66 秒/条**, 88 条要一个半小时。而 JS 侧与 Python 侧的口径等价性另有
`check_jptok_js.mjs` / `check_search.mjs` 在锁, 这里只需要"和指标同一套尺"。

用法(先导片段):
    py -3.13 eval_golden.py --list <榜单> --lens 11 --errs 0 --dump-queries <tsv>
    py -3.13 tools/diagnose_retrieval_misses.py --dump <tsv>
"""
import argparse
import io
import json
import os
import sys

import numpy as np

from guard import guard_help        # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
from eval_golden import norm, same        # noqa: E402  曲名口径复用同一份
from lookup import group_of, pitch_and_oct  # noqa: E402  音高口径复用同一份


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True, help="eval_golden --dump-queries 导出的 TSV")
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--top", type=int, default=5)
    ap.add_argument("--out", default=r"D:\Documents_D\_analysis\检索漏报逐条.tsv")
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    idx = []
    for r in rows:
        p, _o = pitch_and_oct(r.get("score") or "")
        if p:
            idx.append((r, p, np.frombuffer(p.encode(), dtype=np.uint8)))
    print(f"语料 {len(rows)} 首 -> 有旋律 {len(idx)} 份  ({a.data})")

    qs = []
    for i, ln in enumerate(io.open(a.dump, encoding="utf-8")):
        if i == 0 or not ln.strip():
            continue
        c = ln.rstrip("\n").split("\t")
        if len(c) >= 3:
            qs.append(c)
    print(f"查询 {len(qs)} 条  ({a.dump})")

    h1 = h3 = h5 = 0
    miss = []
    ranks = []
    for lst, query, expect in qs:
        frag = query.split()
        L = len(frag)
        qa = np.frombuffer("".join(frag).encode(), dtype=np.uint8)
        sc = []
        for r2, p2, ar2 in idx:
            if len(ar2) < L:
                continue
            wnd = np.lib.stride_tricks.sliding_window_view(ar2, L)
            sc.append((int((wnd != qa).sum(axis=1).min()), norm(group_of(r2.get("title"))), r2.get("title")))
        sc.sort(key=lambda x: x[0])
        e = norm(expect)
        rank = next((k + 1 for k, s in enumerate(sc) if same(e, s[1])), 0)
        ranks.append(rank)
        h1 += rank == 1
        h3 += 0 < rank <= 3
        h5 += 0 < rank <= 5
        if rank == 0 or rank > a.top:
            miss.append((lst, query, expect, sc[:a.top]))

    print()
    print("名次分布: " + "  ".join(f"#{k}:{ranks.count(k)}" for k in sorted(set(ranks)) if k <= 10)
          + (f"  #>10:{sum(1 for x in ranks if x > 10)}" if any(x > 10 for x in ranks) else ""))
    print(f"命中: Top1 {h1}/{len(qs)} = {h1 * 100.0 / len(qs):.1f}%   Top3 {h3}   Top5 {h5}")
    print(f"前 {a.top} 名里找不到期望曲名的: {len(miss)} 条")
    for lst, query, expect, top in miss:
        # 片段里不同音级的个数: 全是同一个音(如 `1 1 1 1 1 1 1 1 1 1 1`)时, 任何谱都能以 0 错音命中,
        # 排名纯属并列里的任意先后 —— 这种漏报是**评测取样**的假漏报, 不是检索的锅。
        nd = len(set(query.split()))
        print(f"\n  期望 《{expect}》  查询 `{query}`   不同音级 {nd} 个   ({lst})")
        for rk, (d, g, t) in enumerate(top, 1):
            print(f"      #{rk} 错音 {d}  {g}    (谱名 {t})")
    with io.open(a.out, "w", encoding="utf-8") as g:
        g.write("期望\t查询\t榜单\t本工具Top1曲名\tTop1错音\n")
        for lst, query, expect, top in miss:
            g.write(f"{expect}\t{query}\t{lst}\t{top[0][1] if top else ''}\t{top[0][0] if top else ''}\n")
    print(f"\n漏报清单 -> {a.out}")


if __name__ == "__main__":
    main()
