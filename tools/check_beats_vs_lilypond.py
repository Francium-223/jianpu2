# -*- coding: utf-8 -*-
"""逐事件比对 jptok 的时值模型 vs 参考实现(jianpu-ly→Lilypond 的 .ly)。**只读。**

按 **section** 对齐(整行 needle 会被"某些 section 不在 .ly 里 / 重复段展开"打败):
把某个 section 的"音级序列"拿到 `.ly` 的事件流里找, 取时值吻合最好的一次出现。

这条是**可靠的那把尺子**(与 `check_bars_vs_lilypond.py` 的粗比对相对): 比的是每个事件的
**时值**, 与"它落在小节哪个位置"无关。2026-09-28 的实测: 修掉 `q-` 之后 **2160 / 2160 = 100%**
一致 —— 也就是说 jptok 的时值模型与参考实现逐事件相同。
"""
import collections
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, "train-data-seq", "img")
DB = r"D:\Documents_D\jianpu-db\data.jsonl"
LILY_BEAT = {1: 4.0, 2: 2.0, 4: 1.0, 8: 0.5, 16: 0.25, 32: 0.125, 64: 0.0625}
DASH = re.compile(r"^([cqsdh]+)-$")


def ly_events(path):
    src = io.open(path, encoding="utf-8", errors="replace").read()
    out = []
    for m in re.finditer(r'\\note-mod\s+"([^"]*)"\s+([a-gr][\',]*)(\d+)(\.*)', src):
        d, dur, dots = m.group(1), int(m.group(3)), m.group(4)
        if d in ("\u2013", "\u2014", "-"):
            d = "-"
        elif not re.match(r"^[0-7]$", d):
            d = "?"
        b = LILY_BEAT.get(dur, 4.0 / dur)
        out.append((d, b * (1.5 if dots else 1.0)))
    return out


def tok_digit(t):
    if t == "|":
        return "|"
    if t == "-" or DASH.match(t or ""):
        return "-"
    p = jptok.parse_token(t)
    if p is None:
        return "?"
    return "0" if p[0] is None else str(p[0])


def tok_beat(t):
    """复刻 `recover_bars` 的时值口径 —— 现在两边都走 `jptok.beat`, 所以 `q-` = 0.5 拍。

    (2026-09-28 之前这里是硬编码 `return 1.0`, 用来**暴露**那个"不看字母"的偏差;
     偏差修掉之后就该直接吃 `jptok.beat`, 于是这条检查从"报 10 处分歧"变成"0 处分歧"。)
    """
    if t == "|":
        return None
    if t == "-" or DASH.match(t or ""):
        return jptok.beat(t)             # `-` = 1.0; `q-` = 字母说的时值(0.5)
    if jptok.parse_token(t) is None:
        return 0.0
    return jptok.beat(t)


def main():
    ly_of = {}
    for p in os.listdir(IMG):
        if p.endswith(".ly"):
            ly_of[os.path.splitext(p)[0]] = os.path.join(IMG, p)
    mism = collections.Counter()
    examples = []
    tot = same = 0
    per_file = collections.Counter()
    sec_matched = sec_total = 0
    dash_letter = collections.Counter()
    for l in io.open(DB, encoding="utf-8"):
        if not l.strip():
            continue
        row = json.loads(l)
        # 全库统计: 带字母的短横
        for t in (row.get("score") or "").split():
            m = DASH.match(t or "")
            if m and m.group(1) != "c":
                dash_letter[t] += 1
        stem = os.path.splitext(row["file"][0])[0]
        path = ly_of.get(stem)
        if not path:
            continue
        ly = ly_events(path)
        lyd = [d for d, _b in ly]
        for sec in row.get("sections") or []:
            toks = [t for t in (sec.get("score") or "").split()]
            if len(toks) < 8:
                continue
            sec_total += 1
            cp = [(tok_digit(t), tok_beat(t)) for t in toks if t != "|"]
            if not cp:
                continue
            cpd = [d for d, _b in cp]
            n = len(cpd)
            best = None
            for s in range(0, len(lyd) - n + 1):
                if lyd[s:s + n] != cpd:
                    continue
                agree = sum(1 for k in range(n) if abs(cp[k][1] - ly[s + k][1]) < 1e-9)
                if best is None or agree > best[0]:
                    best = (agree, s)
            if best is None:
                continue
            sec_matched += 1
            agree, s = best
            tot += n
            same += agree
            f = row["file"][0]
            a0, n0 = per_file.get(f, (0, 0))
            per_file[f] = (a0 + agree, n0 + n)
            for k in range(n):
                if abs(cp[k][1] - ly[s + k][1]) > 1e-9:
                    mism[(cp[k][0], cp[k][1], ly[s + k][1])] += 1
                    if len(examples) < 10:
                        examples.append((f, sec.get("subtitle"), k, cp[k][0], cp[k][1], ly[s + k][1]))
    print("section: %d / %d 在 .ly 里找到对应" % (sec_matched, sec_total))
    print("逐事件时值比对: %d / %d 一致 = %.2f%%" % (same, tot, 100.0 * same / tot if tot else 0))
    print("\n不一致的 (音级, jptok 拍, .ly 拍) 类别:")
    for (d, a, b), c in mism.most_common(15):
        print("   音级 %-3s jptok=%-7s .ly=%-7s  %d 次" % (d, a, b, c))
    print("\n样例:")
    for e in examples[:8]:
        print("   ", e)
    print("\n按文件(最差在前):")
    for f, (a, n) in sorted(per_file.items(), key=lambda x: x[1][0] / max(1, x[1][1]))[:15]:
        print("   %-22s %3d/%3d = %5.1f%%" % (f, a, n, 100.0 * a / max(1, n)))
    print("\n全库带字母短横(非 c)统计:", dash_letter.most_common(8), "共", sum(dash_letter.values()))


if __name__ == "__main__":
    main()
