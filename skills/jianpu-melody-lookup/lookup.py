#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""简谱旋律查歌 —— 给一段旋律(简谱唱名数字), 找出它最可能是哪首歌。

自包含: 只依赖 `data.jsonl`(本 skill 自带, 即 HF 数据集 chinese-jianpu-corpus 的那一份)
+ numpy。**不需要**仓库里的 batch-out / images-prep 等中间产物。

用法:
  python lookup.py 51223323323531
  python lookup.py "5 1 2 2 3 3 2 3 3 2 3 5 3 1" --top 10
  python lookup.py 512233 6675 --top 5 --json      # 多段一起查(分数相加)
  python lookup.py 512233 --indel 1                # 容忍漏唱/多唱一个音

输入: 只认 1-7(简谱唱名); `,6` 低八度, `'1` 高八度, 其它字符忽略。
输出: 按"最小错音数"排序的候选, 附标题/出处/status, 末列为**八度差异**
      (主排序故意丢八度以宽容哼唱; 并列时看八度差能分开《水手》那类只差末两音低八度的歌)。
"""
import argparse
import json
import os
import re
import sys

import numpy as np

# 段落权重(用户 2026-09 规格, 见 jianpu2/README_PIPELINE.md §六) —— **不复制第二份**,
# 直接从 `jianpu2/tools/melody_search.py` 借同一份实现(三处引擎口径一致)。
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "tools"))
try:
    from melody_search import sec_weight, sec_label, section_map, sec_at     # noqa: E402
except Exception:                                   # 独立部署时没有 tools/ -> 退化成"无段落权重"
    def sec_weight(_n): return 1.0
    def sec_label(_n): return ""
    def section_map(_r, _n): return []
    def sec_at(_s, _i, _n): return ""

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gate  # noqa: E402  **自检门**


def _default_data():
    """数据在哪: ① 环境变量 ② **从本文件所在目录向上逐级找** data.jsonl。

    向上找(而不是写死 "..")是为了同时满足两种放法:
      * 单独拷走这个目录, 数据就在同目录            -> <skill>/data.jsonl
      * 放进 HF 数据集仓库(HF 上路径是 skill/jianpu-melody-lookup/lookup.py,
        而 data.jsonl 在**仓库根**)                -> 上两级才找得到
    """
    env = os.environ.get("JIANPU_DATA")
    if env:
        return env
    d = HERE
    for _ in range(4):
        p = os.path.join(d, "data.jsonl")
        if os.path.exists(p):
            return p
        nd = os.path.dirname(d)
        if nd == d:
            break
        d = nd
    return os.path.join(HERE, "data.jsonl")


DEFAULT_DATA = _default_data()
# ⚠ token 口径必须走 jptok(全库唯一实现)。原来这里自写窄正则 `^([qsdh]*)([,']*)([0-9x])`:
# 它**不认 `c` 前缀时值**(KeepLength 的写法, 如 `c6.`)、也不认变音记号 —— 于是这些 token 被静默丢掉,
# 音序**错位**, 连"精确命中"都会消失(2026-09-25 实测: `33565653253` 在《神々が恋した幻想郷》里
# 明明 0 错命中, lookup 却只报出 1 错的别的歌)。这与 2026-09-23"索引丢音"是同一类坑。
try:
    import jptok as _jptok                       # 同一目录下就有(唯一实现)
except Exception:
    _jptok = None
TOKRE = re.compile(r"^([qsdh]*)([,']*)([0-9x])")   # 兜底: 只在没有 jptok 时用(窄, 但口径写明白)
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
SKIP = "0x"
# 改编/器乐版本: 只在**并列**时降权, 不影响主排序(它们也是真歌, 只是不适合当"你哼的那首")
BADWORD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")


def pitch_and_oct(score):
    """`score` 字段 -> (音高串, 八度串)。丢休止 0 / 念白 x; 两者逐音对齐。**走 jptok(唯一实现)**。"""
    p, o = [], []
    for t in (score or "").split():
        if _jptok is not None:
            got = _jptok.parse_token(t)
            if got is None:                      # 不是 token(记号/说明文字)
                continue
            dig, _acc, off = got
            if dig is None:                      # 休止 0 / 念白 x
                continue
            p.append(str(dig))
            o.append(off)
        else:                                    # 兜底口径(窄正则)
            m = TOKRE.match(t)
            if not m:
                continue
            _pre, acc, dig = m.groups()
            if dig in SKIP:
                continue
            p.append(dig)
            o.append(acc.count(",") - acc.count("'"))
    return "".join(p), o


def group_of(title):
    """曲名分组: 同一首歌的不同版本(`…主题曲`/`…简谱`/`…_2`)算一首。"""
    base = (title or "").translate(ZW).split("__")[0]
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("frags", nargs="+", help="旋律片段(可多个), 如 `51223323323531`")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--indel", type=int, default=0, help="容忍漏/多唱的音数(1 约慢 10 倍)")
    ap.add_argument("--data", default=DEFAULT_DATA)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    gate.gate(a.data)          # **自检门**

    if not os.path.exists(a.data):
        sys.exit(f"找不到数据集: {a.data}\n(可设环境变量 JIANPU_DATA 指向 data.jsonl)")
    QS, QOFF = [], []
    for raw in a.frags:
        ms = list(re.finditer(r"([,']*)([1-7])", raw))
        q = "".join(m.group(2) for m in ms)
        if len(q) < 5:
            sys.exit(f"片段太短({len(q)} 个音), 至少 5 个音: {raw}")
        QS.append(q)
        QOFF.append([m.group(1).count(",") - m.group(1).count("'") for m in ms])

    rows = []
    with open(a.data, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if ln:
                rows.append(json.loads(ln))

    groups = {}
    for r in rows:
        p, o = pitch_and_oct(r.get("score"))
        if len(p) < min(len(x) for x in QS):
            continue
        groups.setdefault(group_of(r.get("title")), []).append(
            (r, np.frombuffer(p.encode("ascii", "ignore"), dtype=np.uint8), o))

    def variants(s):
        out = [s] + ([s[:i] + s[i + 1:] for i in range(len(s))] if a.indel >= 1 else [])
        return [np.frombuffer(v.encode("ascii", "ignore"), dtype=np.uint8) for v in out]

    QVAR = [variants(s) for s in QS]
    res = []
    for g, ents in groups.items():
        total, det, ok = 0, [], True
        for vb_list in QVAR:
            best = None
            for vb in vb_list:
                for r, arr, _o in ents:
                    if len(arr) < len(vb):
                        continue
                    w = np.lib.stride_tricks.sliding_window_view(arr, len(vb))
                    mism = (w != vb).sum(axis=1)
                    m = int(mism.min())
                    same = np.where(mism == m)[0]          # 同分的所有位置
                    if len(same) == 1:
                        i = int(same[0])
                    else:
                        # 同分: 取段落权重最高的那处(副歌/主歌 > 间奏 > 整曲 > 前奏/尾奏/发狂钢琴)
                        secmap = r.get("_secmap")
                        if secmap is None:
                            secmap = section_map(r, len(arr))
                            r["_secmap"] = secmap
                        i = max((int(x) for x in same),
                                key=lambda p: (sec_weight(sec_at(secmap, p, len(vb))), -p))
                    if best is None or m < best[0]:
                        best = (m, i, r)
            if best is None:
                ok = False
                break
            total += best[0]
            det.append(best)
        if ok and det:
            res.append((total, g, det))

    def pop_key(g):
        for _ in range(3):
            k = re.sub(r"(?:[-_（(]?\s*(?:简谱|歌曲类|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱)\s*[)）]?)+$", "", g)
            k = re.sub(r"(?<=[\u4e00-\u9fff])[0-9]$", "", k)
            if k == g or not k:
                break
            g = k
        return g

    pop = {}
    for g, ents in groups.items():
        pop[pop_key(g)] = pop.get(pop_key(g), 0) + len(ents)

    # 知名度代理: 该曲 artist/tag(非「分类/…」)里某个名字在语料里出现的最大次数。
    # 公式与 jianpu-web/tools/build_web_data.py、tools/melody_search.py **必须一致**。
    _hot = {}
    for _e in rows:      # rows = 本次加载的 data.jsonl
        for _n in list(_e.get("artist") or []) + [t for t in (_e.get("tag") or []) if not str(t).startswith("分类/")]:
            _hot[_n] = _hot.get(_n, 0) + 1

    def hot_of(head):
        names = list(head.get("artist") or []) + [t for t in (head.get("tag") or []) if not str(t).startswith("分类/")]
        return max([_hot.get(x, 0) for x in names] or [0])

    def secw_of(head, pos, n):
        secmap = head.get("_secmap")
        if secmap is None:
            p2, _o2 = pitch_and_oct(head.get("score"))
            secmap = section_map(head, len(p2))
            head["_secmap"] = secmap
        return sec_weight(sec_at(secmap, pos, n))

    def sort_key(item):
        total, g, det = item
        head = det[0][2]
        # 同分时段落权重高的先(副歌 > 主歌 > 间奏 > 整曲 > 前奏/尾奏/发狂钢琴) —— 用户 2026-09 规格
        secw = max(secw_of(d[2], d[1], len(QS[k])) for k, d in enumerate(det))
        # 注意 hot 取**负号**: 语料里谱多的歌手 = 更可能被人哼到的那首, 要排前面
        return (total, -secw, pop.get(pop_key(g), 0), -hot_of(head),
                1 if BADWORD.search(head.get("title") or "") else 0,
                len(head.get("title") or ""), g)

    res.sort(key=sort_key)
    out = []
    for total, g, det in res[:a.top]:
        head = det[0][2]
        p, o = pitch_and_oct(head.get("score"))
        i = det[0][1]
        n = len(QS[0])
        odiff = None
        if QOFF[0] and i + n <= len(o):
            odiff = sum(1 for k in range(n) if QOFF[0][k] != o[i + k])
        out.append({
            "rank": len(out) + 1, "errors": total, "title": head.get("title"),
            "group": g, "source": head.get("source"), "status": head.get("status"),
            "tags": head.get("tags") or [], "n_notes": head.get("n_notes"),
            "octave_diff": odiff, "matched_at": i,
            "sec": sec_at(head.get("_secmap"), i, n),
            "sec_cn": sec_label(sec_at(head.get("_secmap"), i, n)),
            "sec_w": sec_weight(sec_at(head.get("_secmap"), i, n)),
            "matched": p[i:i + n] if i + n <= len(p) else p[i:],
        })
    if a.json:
        print(json.dumps({"query": QS, "index_songs": len(groups),
                          "index_scores": sum(len(v) for v in groups.values()),
                          "results": out}, ensure_ascii=False, indent=2))
    else:
        print(f"查询 {(' | '.join(QS))}   库 {len(groups)} 首 / "
              f"{sum(len(v) for v in groups.values())} 份谱   至少 5 音\n")
        print(f"{'#':>2} {'错音':>4} {'八度差':>5}  {'曲名':<26} {'状态':<4} 出处")
        for r in out:
            od = "-" if r["octave_diff"] is None else str(r["octave_diff"])
            sec = ("〔%s〕" % r["sec_cn"]) if r.get("sec_cn") and r["sec_cn"] != "整曲" else ""
            print(f"{r['rank']:>2} {r['errors']:>4} {od:>5}  {str(r['title'])[:24]:<26} "
                  f"{str(r['status']):<4} {r['source']} {sec}")
        if out and out[0]["matched"]:
            print(f"\n命中片段: {out[0]['matched']}")


if __name__ == "__main__":
    main()
