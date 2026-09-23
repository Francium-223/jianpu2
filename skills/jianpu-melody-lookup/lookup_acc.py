# -*- coding: utf-8 -*-
"""旋律查歌 —— **升降号感知**的匹配(口径: 发送从严, 接收从宽)。

用户口径(原话): 「输入 5 能匹配到 #5; 输入 #5 匹配 #5 能更精确。发送从严、接收从宽。」

所以**不能**把 #5 归一化成 5。记谱里每个音分成两部分:
    音级 1-7  +  变音记号 ∈ {自然(空), #, b}
匹配用**非对称代价**:
    查询\库里     自然    #      b
    自然          0       c1     c1      <- 用户没写记号: 宽容, 但比不上精确命中
    #             c2      0      c3      <- 用户写了 #: 命中 # 才算 0, 自然要罚, b 罚更多
    b             c2      c3     0
  默认 c1=1(可以把"没写记号"当成"少一个信息", 罚 1), c2=2(写了记号却没对上, 罚重),
       c3=3(写反了, 罚最重)。可用 --c1/--c2/--c3 调。
排序: 总代价 -> 精确命中数(更多者优) -> 热度 -> 非改编 -> 名短。
输出里**显示每个音的实际记号**(如 `6 3 7 3 1 2 3 2 #5`), 让用户看见差在哪。
"""
import argparse
import io
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import jptok                        # noqa: E402  **唯一 token 口径**
import gate                         # noqa: E402  **自检门**
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
BAD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")
TAIL = re.compile(r"(?:[-_（(]?\s*(?:简谱|歌曲类|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱)\s*[)）]?)+$")
# 这里**不再**定义 token 正则: 一律 jptok.parse_token / jptok.query(唯一口径)


def toks_of(score):
    """-> [(音级, 变音(0/1/-1), 八度, 原token)]，休止/念白剔除。

    解析走 jptok.parse_token(唯一口径), 不再自带正则 —— 之前 TOK 与 jptok 的差别
    正是"升降号被整段丢掉"那次事故的同一个坑。
    """
    out = []
    for t in (score or "").split():
        p = jptok.parse_token(t)
        if p is None or p[0] is None:
            continue
        out.append((p[0], p[1], p[2], t))
    return out


def query_of(raw):
    return jptok.query(raw)


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


def cost(qd, qa, cd, ca, c1, c2, c3):
    """单个音的非对称代价。"""
    if qd != cd:
        return c3 + 1                      # 音级就不对, 最重
    if qa == ca:
        return 0                           # 完全一致(含记号)
    if qa == 0:
        return c1                          # 用户没写记号, 库里写了 -> 宽容
    if ca == 0:
        return c2                          # 用户写了记号, 库里是自然 -> 罚
    return c3                              # # vs b, 写反了


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frags", nargs="+")
    ap.add_argument("--data", default=os.path.join(HERE, "data.jsonl"))
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--c1", type=int, default=1)
    ap.add_argument("--c2", type=int, default=2)
    ap.add_argument("--c3", type=int, default=3)
    ap.add_argument("--maxcost", type=int, default=0, help="0 = 自动(先严后宽)")
    a = ap.parse_args()
    gate.gate(a.data)          # **自检门**

    Q = []
    for raw in a.frags:
        q = query_of(raw)
        if len(q) >= 5:
            Q.append(q)
    if not Q:
        sys.exit("片段至少 5 个音(只认 1-7; 可带 # 或 b)")

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    groups = {}
    for r in rows:
        tk = toks_of(r.get("score") or "")
        if len(tk) >= min(len(q) for q in Q):
            src = r.get("source") or ""
            src = src[0] if isinstance(src, list) else src
            groups.setdefault(group_of(r.get("title")), []).append((r.get("title") or "", tk, src))

    pop = {}
    for g, v in groups.items():
        pop[pop_key(g)] = pop.get(pop_key(g), 0) + len(v)

    res = []
    for g, members in groups.items():
        total, exact, det, ok = 0, 0, [], True
        for q in Q:
            n = len(q)
            best = None
            for title, tk, src in members:
                if len(tk) < n:
                    continue
                for i in range(len(tk) - n + 1):
                    c = 0
                    for k in range(n):
                        c += cost(q[k][0], q[k][1], tk[i + k][0], tk[i + k][1], a.c1, a.c2, a.c3)
                        if best and c >= best["cost"]:
                            break
                    if best is None or c < best["cost"]:
                        best = {"cost": c, "at": i, "title": title, "src": src, "tk": tk, "q": q}
            if best is None:
                ok = False
                break
            total += best["cost"]
            exact += sum(1 for k in range(n) if best["q"][k][1] == best["tk"][best["at"] + k][1])
            det.append(best)
        if ok and det:
            res.append((total, -exact, g, det))

    res.sort(key=lambda x: (x[0], x[1], -pop.get(pop_key(x[2]), 0),
                            1 if BAD.search(x[2]) else 0, len(x[2]), x[2]))
    if a.maxcost:
        res = [x for x in res if x[0] <= a.maxcost]
    if not res:
        print("没找到。缩短到 6-7 个音再试。")
        return
    best_cost = res[0][0]
    print(f"查询 {' | '.join(''.join(str(d) + ('#' if a2 == 1 else 'b' if a2 == -1 else '')
                                    for d, a2, _o in q) for q in Q)}")
    print(f"库 {len(groups)} 首 · 最佳代价 {best_cost}（0 = 连升降号都一模一样）\n")
    for i, (total, negx, g, det) in enumerate(res[:a.top], 1):
        h = det[0]
        seg = " ".join(("#" if x[1] == 1 else "b" if x[1] == -1 else "") + str(x[0])
                       for x in h["tk"][h["at"]:h["at"] + len(h["q"])])
        print(f"{i:>2} 代价 {total:>3} 记号命中 {-negx:>2}/{len(h['q'])}  {g[:22]:<24} {h['src']}")
        print(f"     库内该段: {seg}")
        print(f"     你的输入: {' '.join(('#'.join(['','']) if False else ('#' if a2 == 1 else 'b' if a2 == -1 else '') + str(d)) for d, a2, _o in h['q'])}")


if __name__ == "__main__":
    main()
