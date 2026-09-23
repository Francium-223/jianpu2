# -*- coding: utf-8 -*-
"""旋律查歌: 先用**几乎精确**的匹配(Top-1), 找不到再自动放宽到容忍 1-2 个音。

用户口径(2026-09-23): 「差一个降号就搜不出来那是什么水准」——所以默认就要能容忍
一个音的差异; 但结果里必须**如实标出错音数**, 而不是假装精确命中。

用法:
  py -3.13 lookup_exact.py 637312325
  py -3.13 lookup_exact.py 637312325 --top 5
  py -3.13 lookup_exact.py 637312325 --maxerr 2      # 允许放宽到 2 个音
"""
import argparse
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TOKRE = re.compile(r"^([qsdh]*)([,']*)([0-9x])")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
BAD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")
TAIL = re.compile(r"(?:[-_（(]?\s*(?:简谱|歌曲类|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱)\s*[)）]?)+$")


def group_of(t):
    base = (t or "").translate(ZW).split("__")[0]
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def pitches(score):
    """-> (音高串, 八度串)  : 与库/前端统一口径, 丢 0/x。"""
    p, o = [], []
    for t in score.split():
        m = TOKRE.match(t)
        if not m:
            continue
        _pre, acc, dig = m.groups()
        if dig in "0x":
            continue
        p.append(dig)
        o.append(acc.count(",") - acc.count("'"))
    return "".join(p), "".join(str(x) for x in o)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frags", nargs="+")
    ap.add_argument("--data", default=os.path.join(HERE, "data.jsonl"))
    ap.add_argument("--top", type=int, default=5)
    ap.add_argument("--maxerr", type=int, default=2, help="允许放宽到几个音")
    a = ap.parse_args()

    QS = []
    for raw in a.frags:
        d = "".join(m.group(2) for m in re.finditer(r"([,']*)([1-7])", raw))
        if len(d) >= 5:
            QS.append(d)
    if not QS:
        sys.exit("片段至少 5 个音(只认 1-7)")

    rows = [json.loads(l) for l in open(a.data, encoding="utf-8") if l.strip()]
    groups = {}
    for r in rows:
        p, o = pitches(r.get("score") or "")
        if len(p) < min(len(x) for x in QS):
            continue
        groups.setdefault(group_of(r.get("title")), []).append((r, p, o))

    pop = {}
    for g in groups:
        k = g
        for _ in range(3):
            k2 = TAIL.sub("", k)
            if k2 == k or not k2:
                break
            k = k2
        pop[k] = pop.get(k, 0) + len(groups[g])

    qs = [np.frombuffer(x.encode(), dtype=np.uint8) for x in QS]
    res = []
    for g, members in groups.items():
        total, det = 0, []
        ok = True
        for q in qs:
            best = None
            for r, p, o in members:
                arr = np.frombuffer(p.encode(), dtype=np.uint8)
                if len(arr) < len(q):
                    continue
                w = np.lib.stride_tricks.sliding_window_view(arr, len(q))
                mm = (w != q).sum(axis=1)
                i = int(mm.argmin())
                if best is None or mm[i] < best[0]:
                    best = (int(mm[i]), i, r, o)
            if best is None:
                ok = False
                break
            total += best[0]
            det.append(best)
        if ok and det and total <= a.maxerr:
            res.append((total, g, det))

    def key(x):
        total, g, det = x
        head = det[0][2]
        return (total, -pop.get(group_of(head.get("title")), 0),
                1 if BAD.search(head.get("title") or "") else 0,
                len(head.get("title") or ""), g)

    res.sort(key=key)
    if not res:
        print(f"没找到(允许 {a.maxerr} 个音差异内)。建议缩短到 6-7 个音再试。")
        return
    print(f"查询 {' | '.join(QS)}   库 {len(groups)} 首   允许错音 ≤ {a.maxerr}\n")
    print(f"{'#':>2} {'错音':>4}  {'曲名':<26} 出处")
    for i, (total, g, det) in enumerate(res[:a.top], 1):
        head = det[0][2]
        flag = "  ← 完全一致" if total == 0 else ""
        print(f"{i:>2} {total:>4}  {str(head.get('title'))[:24]:<26} {head.get('source')}{flag}")


if __name__ == "__main__":
    main()
