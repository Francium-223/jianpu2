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
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import jptok                      # **唯一口径**: token 解析/时值/小节线都从它来
import gate                       # **自检门**
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
BAD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")
TAIL = re.compile(r"(?:[-_（(]?\s*(?:简谱|歌曲类|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱)\s*[)）]?)+$")
# 数字前可带升降号, 数字后可带八度与附点


def norm_digits(raw):
    """任意写法 -> (音高数字串, 八度偏移列表)。升降号丢掉。

    **已废**: 这个实现用 `finditer` 在整段文本上逐字符抠数字, 而 `score` 里每个音符都带
    时值前缀/后缀(`q3`/`5s`/`6c.`) -> 数字被重复计入, 231 个音符被膨胀成 377 个, 凭空造出
    不存在的匹配(实测: `33565653253` 被谎报在 `th10_06` 的位置 0 "完全一致", 而那份谱里
    根本没有这个音串)。**唯一口径是 jptok**: 先把文本 split 成 token, 再逐 token 解析。
    这里保留函数名只为兼容, 实现改为转发 jptok.seq。
    """
    notes = jptok.seq(raw)
    return "".join(str(d) for d, _a, _o in notes), [o for _d, _a, o in notes]


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
    gate.gate(a.data)          # **自检门**: 已知答案用例不过就不许出结果

    segs = []
    for raw in a.frags:
        # **查询也用 jptok**(唯一口径): 之前误用 norm_digits(raw) 解析用户输入,
        # 它是给整段谱面设计的, 对"纯数字串"虽然能过但口径不统一。
        notes = jptok.query(raw)
        d = "".join(str(x[0]) for x in notes)
        o = [x[2] for x in notes]
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
        for q in qa:
            best = None
            for m in members:
                # members 的元素是 (title, pitch, octstr, src) —— **必须显式取值, 不能按数量解包**:
                # 之前写成 `for t, p, o, s in members`, 而某些构造路径下元素不是 4 元组,
                # 解包直接抛 ValueError -> best 保持 None -> **被当成"0 错命中"**,
                # 于是给出"完全一致"的假结论(实测踩过: 33565653253 被谎报命中神恋)。
                t, p = m[0], m[1]
                s = m[3] if len(m) > 3 else ""
                arr = np.frombuffer(p.encode(), dtype=np.uint8)
                if len(arr) < len(q):
                    continue
                w = np.lib.stride_tricks.sliding_window_view(arr, len(q))
                mm = (w != q).sum(axis=1)
                i = int(mm.argmin())
                if best is None or int(mm[i]) < best["err"]:
                    best = {"err": int(mm[i]), "at": i, "title": t, "src": s,
                            "pitch": p, "group": g}
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
    # **不显示八度差**: 用户口径「一般用户标升降的概率都比标八度的高」—— 八度不参与判断。
    print(f"{'#':>2} {'错音':>4}  {'曲名':<28} 出处")
    for i, (total, g, det) in enumerate(res[:a.top], 1):
        h = det[0]
        flag = "   ← 完全一致" if total == 0 else ""
        print(f"{i:>2} {total:>4}  {g[:26]:<28} {h['src']}{flag}")
        print(f"     库内该段: {' '.join(h['pitch'][h['at']:h['at'] + len(segs[0][0])])}")


if __name__ == "__main__":
    main()
