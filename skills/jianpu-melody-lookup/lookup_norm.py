# -*- coding: utf-8 -*-
"""旋律查歌 —— **token 归一化**版(用户口径: "你就不能把这些 token 都归一化吗")。

归一化口径(输入与语料**同一套**):
  * 升降号丢掉: `#5` `b3` `♯4` `♭6` 一律按 `5` `3` `4` `6` 处理
    (实测库里 395 万 token **没有一个**带升降号, 所以这是"把两边都归一化", 不是放宽)
  * 八度记号 `,` / `'` 只影响**并列判别**, 不参与主排序
  * 休止 `0` / 念白 `x` / 时值字母 q s d h / 附点 `.` / 延长 `-` / 连音 `~` 全部丢掉
  * 片段之间用空格/逗号/分号/竖线分开; **空格不分段**(段内空格当无意义)

匹配: 每段在每份谱上求最小错音数(滑窗), 组内取最优, 各段相加; 按"错音→热度→非改编→名短"排序。
默认报**全部**结果并如实标错音数, 不做"精确优先"以外的加工。

用法:
  py -3.13 lookup_norm.py 637312325
  py -3.13 lookup_norm.py 637312325 --top 5 --maxerr 1
"""
import argparse
import io
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
BAD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")
TAIL = re.compile(r"(?:[-_（(]?\s*(?:简谱|歌曲类|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱)\s*[)）]?)+$")
# 数字前可带升降号, 数字后可带八度与附点
NOTE = re.compile(r"([#b♯♭]?)([,\']*)([1-7])([,\']*)")


def norm_digits(raw):
    """任意写法 -> (音高数字串, 八度偏移列表)。升降号丢掉。"""
    p, o = [], []
    for m in NOTE.finditer(raw):
        _acc, pre, dig, post = m.groups()
        p.append(dig)
        o.append((pre + post).count(",") - (pre + post).count("'"))
    return "".join(p), o


def group_of(t):
    base = (t or "").translate(ZW).split("__")[0]
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def pop_key(g):
    k = g
    for _ in range(3):
        k2 = TAIL.sub("", k)
        if k2 == k or not k2:
            break
        k = k2
    return k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frags", nargs="+")
    ap.add_argument("--data", default=os.path.join(HERE, "data.jsonl"))
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--maxerr", type=int, default=3)
    a = ap.parse_args()

    segs = []
    for raw in a.frags:
        d, o = norm_digits(raw)
        if len(d) >= 5:
            segs.append((d, o))
    if not segs:
        sys.exit("片段至少 5 个音(只认 1-7; #/b 会被丢掉)")

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    groups = {}          # 组名 -> [(曲名, 音高串, 八度串, 出处)]
    for r in rows:
        p, o = norm_digits(r.get("score") or "")
        if not p:
            continue
        src = r.get("source") or ""
        src = src[0] if isinstance(src, list) else src
        g = group_of(r.get("title"))
        groups.setdefault(g, []).append((r.get("title") or "", p, "".join(str(x) for x in o), src))

    want = min(len(d) for d, _o in segs)
    groups = {g: v for g, v in groups.items() if any(len(p) >= want for _t, p, _o, _s in v)}
    pop = {}
    for g, v in groups.items():
        k = pop_key(g)
        pop[k] = pop.get(k, 0) + len(v)

    qa = [np.frombuffer(d.encode(), dtype=np.uint8) for d, _o in segs]
    res = []
    for g, members in groups.items():
        total, det, ok = 0, [], True
        for (d, oq), q in zip(segs, qa):
            best = None
            for t, p, o, s in members:
                arr = np.frombuffer(p.encode(), dtype=np.uint8)
                if len(arr) < len(q):
                    continue
                w = np.lib.stride_tricks.sliding_window_view(arr, len(q))
                mm = (w != q).sum(axis=1)
                i = int(mm.argmin())
                if best is None or int(mm[i]) < best["err"]:
                    best = {"err": int(mm[i]), "at": i, "title": t, "src": s,
                            "oct": o, "pitch": p, "qoct": oq, "group": g}
            if best is None:
                ok = False
                break
            total += best["err"]
            det.append(best)
        if ok and det and total <= a.maxerr:
            res.append((total, g, det))

    res.sort(key=lambda x: (x[0], -pop.get(pop_key(x[1]), 0),
                            1 if BAD.search(x[1]) else 0, len(x[1]), x[1]))
    if not res:
        print(f"没找到(允许 ≤{a.maxerr} 个音差异)。缩短到 6-7 个音再试。")
        return
    print(f"查询 {' | '.join(d for d, _ in segs)}   库 {len(groups)} 首   允许错音 ≤{a.maxerr}\n")
    print(f"{'#':>2} {'错音':>4} {'八度差':>6}  {'曲名':<26} 出处")
    for i, (total, g, det) in enumerate(res[:a.top], 1):
        h = det[0]
        n = len(segs[0][0])
        od = "-"
        o, oq = h["oct"], h["qoct"]
        if o and h["at"] + n <= len(o):
            od = str(sum(1 for k in range(n) if int(o[h["at"] + k]) != oq[k]))
        flag = "   ← 完全一致" if total == 0 else ""
        print(f"{i:>2} {total:>4} {od:>6}  {g[:24]:<26} {h['src']}{flag}")


if __name__ == "__main__":
    main()
