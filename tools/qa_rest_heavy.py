# -*- coding: utf-8 -*-
"""抓"休止/延长占绝大多数"的转写 —— 这类是**转写失败**(把歌词/花纹读成了休止), 不是简谱本来的样子。

为什么需要它(2026-09-28 实测):
  扩库后随机抽一首新导入的谱对图核验 —— `一路平安`(qupu123-311039)。图上是一整页**密集的音符+歌词**
  (`0.5 3 2 3 0 2 1 | 3 3 5 3 2 1 | 3 2 3. | …`), 而库里的转写是
  `q1 s1 0 q1 q1 q1 0 - x 0 0 3. - - - 0 - - - 1'. 0 x 0 0 - …` —— **86% 是休止/延长, 几乎没有旋律**。
  它 `status=ocr` 就被收了:流水线有"念白 `x` 异常"的闸(`quarantine_highx.py`), **但休止 `0` 没有闸**。

判据(与本文件同目录的兄弟工具同风格: 只移不删, 默认 dry):
  * `休止/延长占比 = (0 + x + `-` 类 token) / 全部 token`;
  * `>= --ratio 0.70` 且 `token >= --min-tok 40` 才判(样本太短的谱不判 —— 与 quarantine_highx 的
    `MIN_TOK=20`、`NMIN=10` 同思路, 这里取更保守的下限与更高的阈值)。
  实测全库分布: 0.0~0.3 占 93%, `>=0.70` 只有 19 首(其中 17 首 token>=40)。

做法: **移动**到 `scores-suspect/`(照 quarantine_short_scores.py 的先例, 只移不删, 可逆);
之后跑 `parse_scores.py` 它们自然就不在 data.jsonl 里了。

用法:
    py -3.13 tools/qa_rest_heavy.py                 # 只看会移哪些(默认 dry)
    py -3.13 tools/qa_rest_heavy.py --apply
    py -3.13 tools/qa_rest_heavy.py --ratio 0.8 --min-tok 60 --apply
"""
import argparse
import io
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.path.insert(0, HERE)
from guard import guard_help        # noqa: E402
guard_help(__doc__)
sys.stdout.reconfigure(encoding="utf-8")


def dead_ratio(score):
    """(休止/延长 占比, 总 token 数)。休止 `0`/念白 `x`/纯延长 `-`/带时值的延长 `c-` 都算"没旋律"。"""
    toks = (score or "").split()
    if not toks:
        return None, 0
    dead = 0
    for t in toks:
        if t in ("0", "x", "-", "|", "~"):
            dead += 1
        elif t.rstrip("-") in ("c", "q", "s", "d", "h") and t.endswith("-"):
            dead += 1
    return dead / len(toks), len(toks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ratio", type=float, default=0.70, help="休止/延长占比阈值(默认 0.70)")
    ap.add_argument("--min-tok", type=int, default=40, help="token 数下限(太短的不判, 默认 40)")
    ap.add_argument("--apply", action="store_true", help="不给就是 dry-run")
    ap.add_argument("--dest", default=os.path.join(DB, "scores-suspect"))
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8") if l.strip()]
    hits = []
    for r in rows:
        rt, n = dead_ratio(r.get("score"))
        if rt is not None and rt >= a.ratio and n >= a.min_tok:
            hits.append((rt, n, r["file"][0], (r.get("title") or "")[:24]))
    hits.sort(reverse=True)
    print("语料 %d 首; 休止/延长 >= %.2f 且 >= %d token 的: **%d 首**" % (len(rows), a.ratio, a.min_tok, len(hits)))
    for rt, n, fn, t in hits:
        print("   %.2f  %5d token  %-40s %s" % (rt, n, fn[:40], t))
    if not a.apply:
        print("\n(dry-run, 没动任何文件; 加 --apply 才移到 %s)" % a.dest)
        return 0

    os.makedirs(a.dest, exist_ok=True)
    moved = 0
    for rt, n, fn, t in hits:
        src = os.path.join(DB, "scores", fn)
        if os.path.exists(src):
            shutil.move(src, os.path.join(a.dest, fn))
            moved += 1
    print("\n已移到 %s: %d 份(只移不删, 可逆: 移回 scores/ 即恢复)" % (a.dest, moved))
    print("下一步: cd %s && py parse_scores.py   (重建 data.jsonl)" % DB)
    return 0


if __name__ == "__main__":
    sys.exit(main())
