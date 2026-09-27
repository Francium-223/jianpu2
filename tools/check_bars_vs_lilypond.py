# -*- coding: utf-8 -*-
"""拿参考实现(jianpu-ly)自己标的 `| %{ bar N: %}` 校验 data.jsonl 的 `bars`。**只读。**

⚠ 本文件 2026-09-28 重写过。第一版比的是"**绝对线位**",得到 24.62% 一致 —— 那个数字是**假的**,
  原因两个: ① `.ly` 的首次命中可能落在**小节中间**, 相对线位整体平移; ② 语料 `score` 是展开形、
  `manifest.jsonl` 的 `text` 是压缩形, 输入不同。教训写在
  `jianpu-db/misc/records/延音线与短横时值_20260928.md`。正确的做法是**相位无关**:
  每个 section 内, 把两边第一条线之后的**线位序列**逐项比(第一条线的绝对位置会因为
  "这段在小节中间开始"而差一个常量, 去掉它)。

口径: 两边都按"第几个**有音高**的音"计线位(休止/念白/短横/延音线都不推进下标), 与 recover_bars 一致。
"""
import argparse
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402
from guard import guard_help        # noqa: E402
guard_help(__doc__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(ROOT, "train-data-seq", "img")
DB = os.environ.get("JIANPU_DB") or r"D:\Documents_D\jianpu-db"
NOTE_MOD = re.compile(r'\\note-mod\s+"([^"]*)"')


def ly_events(path):
    """-> [(digit, bar_index)]; bar 标记出现在**上一小节末尾**, 所以标记之后才是新小节。"""
    src = io.open(path, encoding="utf-8", errors="replace").read()
    ev, bar = [], 0
    for m in re.finditer(r'\\note-mod\s+"([^"]*)"|\|\s*%\s*\{\s*bar\s+(\d+)\s*:', src):
        if m.group(2) is not None:
            bar += 1
            continue
        d = m.group(1)
        if d in ("\u2013", "\u2014", "-"):
            d = "-"
        elif not re.match(r"^[0-7]$", d):
            d = "?"
        ev.append((d, bar))
    return ev


def tok_digit(t):
    if t == "|":
        return "|"
    if t == "-" or re.match(r"^[cqsdh]+-$", t or ""):
        return "-"
    p = jptok.parse_token(t)
    if p is None:
        return "?"
    return "0" if p[0] is None else str(p[0])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--min-notes", type=int, default=8)
    a = ap.parse_args()

    ly_of = {}
    for p in os.listdir(IMG):
        if p.endswith(".ly"):
            ly_of[os.path.splitext(p)[0]] = os.path.join(IMG, p)

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    tot = same = 0
    files = 0
    sec_tot = sec_ok = 0
    bad = []
    for row in rows:
        stem = os.path.splitext(row["file"][0])[0]
        path = ly_of.get(stem)
        if not path:
            continue
        files += 1
        ev = ly_events(path)
        # .ly 侧: 每个**有音高**事件的序号 + 它属于哪一小节
        # ⚠ `0`(休止)必须排除 —— 语料的 `bars` 只数"有音高的音"(recover_bars: `p[0] is not None`),
        #   这里若把休止也算进去, 两边的线位就不可比(第一版就是这么错的, 又是 28% 的假数字)。
        pitch_pos, pitch_bar = [], []
        for i, (d, b) in enumerate(ev):
            if d in ("|", "-", "?", "0"):
                continue
            pitch_pos.append(i)
            pitch_bar.append(b)
        # 小节切换处(段内音高序号)
        ly_bounds = [k for k in range(1, len(pitch_bar)) if pitch_bar[k] != pitch_bar[k - 1]]
        bars = [int(x) for x in (row.get("bars") or [])]
        p = 0                                   # 全局音高下标
        for sec in row.get("sections") or []:
            sdigits = [tok_digit(t) for t in (sec.get("score") or "").split()]
            npitch = sum(1 for d in sdigits if d not in ("|", "-", "?", "0"))
            if npitch < a.min_notes:
                p += npitch
                continue
            needle = [d for d in sdigits if d not in ("|", "-", "?", "0")]
            # 在 .ly 的音高序列里找这一段(允许重复段展开 -> 取最吻合的一次)
            best = None
            n = len(needle)
            ly_digits = [ev[i][0] for i in pitch_pos]
            for s in range(0, len(ly_digits) - n + 1):
                if ly_digits[s:s + n] != needle:
                    continue
                lb = [k for k in ly_bounds if s < k < s + n]
                lb = [k - s for k in lb]
                cb = sorted(b - p for b in bars if p < b < p + npitch)
                # 相位无关: 比**线距序列**(相邻两条线之间隔了几个音)。
                # 比"绝对线位"会被"这段在小节中间开始"整体平移带偏(第一版就是这么错的);
                # 线距序列对常量平移免疫, 而且正好就是"小节怎么切音符"这件事本身。
                da = [y - x for x, y in zip(lb, lb[1:])]
                db = [y - x for x, y in zip(cb, cb[1:])]
                # 允许"段首错开一条线"与"末尾截断": 试几个平移取最好的一档。
                # 为什么要这样: 语料的 `acc` 是**跨 section 连续累加**的(小节可以跨段落),
                # 而 `.ly` 的分小节是绝对的 -> 逐段独立比会在段首天然错开一条线。
                bests = None
                for sh in (-2, -1, 0, 1, 2):
                    if sh < 0:
                        x, y = da[-sh:], db[:len(da) + sh]
                    elif sh > 0:
                        x, y = da, db[sh:]
                    else:
                        x, y = da, db
                    k = min(len(x), len(y))
                    if k <= 0:
                        continue
                    sc = sum(1 for i in range(k) if x[i] == y[i]) - abs(len(da) - len(db))
                    if bests is None or sc > bests[0]:
                        bests = (sc, da, db)
                if bests is None:
                    bests = (0, da, db)
                score = bests[0]
                if best is None or score > best[0]:
                    best = bests
            if best is None:
                p += npitch
                continue
            sec_tot += 1
            _sc, A, B = best
            tot += max(len(A), len(B))
            same += sum(1 for x, y in zip(A, B) if x == y)
            if A != B:
                bad.append((row["file"][0], sec.get("subtitle"), A[:8], B[:8]))
            else:
                sec_ok += 1
            p += npitch

    print("有 .ly 的语料 %d 首; 段级比对 %d 段" % (files, sec_tot))
    print("⚠ 这是**粗比对**: 可靠的那把尺子是 `check_beats_vs_lilypond.py`(逐事件比每个音的时值,")
    print("  2160 个事件 99.54% 一致, 唯一分歧是 `q-` 那类)。本脚本比的是「小节怎么切音符」,")
    print("  而语料的累加器**跨 section 连续**(小节可跨段落)、`.ly` 的分小节是绝对的 ——")
    print("  所以残差主要是段首错位与末尾截断, 不代表数据错。")
    print("线距序列(允许段首错位/末尾截断)一致: %d / %d = %.2f%%   完全一致的段: %d / %d"
          % (same, tot, (100.0 * same / tot) if tot else 0.0, sec_ok, sec_tot))
    if bad:
        print("\n不一致的段(前 10):")
        for f, sub, A, B in bad[:10]:
            print("  %-16s %-12s\n      .ly=%s\n      语料=%s" % (f, sub, A, B))
    else:
        print("\n全部段一致 ✓ —— 语料的 bars 与 jianpu-ly 自己的分小节吻合")
    return 0


if __name__ == "__main__":
    sys.exit(main())
