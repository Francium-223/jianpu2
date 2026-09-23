#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""语料体检：找"转写失败/重复存储"的曲, 能确定的隔离, 拿不准的只出提案。

第一遍(夜间)抓到"旋律音 < 5"的 14 首垃圾(已隔离, 见 quarantine_short_scores.py)。
这一遍抓三类更隐蔽的:

  A. **明确垃圾**(能自动隔离):
     * 单音占比 >= 90%(整首就一个音在重复, 例: `关山望月` 41 个音全是 `1`)
     * 音符/token < 25%(整份谱几乎全是休止/念白/延长)
     * 音级数 <= 2 且 >= 20 音
  B. **同源完全重复**(能自动去重): 整段 `score` 逐字相同 **且 `source` 也相同**
     —— 同一份谱被存了两个文件名(例: `1=F4_4_深.txt` 与 `牧羊姑娘1=F4_4_深情悠扬地.txt`
     都是 jianpujia-315435)。保留"名字更好"的那份(规则见 keep_better)。
  C. **可疑但拿不准**(只出提案): 单音占比 50~90%、音符/token 25~35%、跨站点的旋律重复
     (两个站各有一份, 内容相同 —— 删了会丢一条出处, 交人决定)。

隔离一律用**移动**(scores/ -> scores-suspect/), 不删; 附 README 说明与恢复方法。

用法:
  python3 jianpu2/tools/audit_corpus_quality.py                 # 只看报告
  python3 jianpu2/tools/audit_corpus_quality.py --apply-junk    # 隔离 A
  python3 jianpu2/tools/audit_corpus_quality.py --apply-dup     # 去重 B
  python3 jianpu2/tools/audit_corpus_quality.py --apply         # A + B
"""
import argparse
import collections
import io
import json
import os
import re
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
SUSPECT = os.path.join(DB, "scores-suspect")
OUT = os.path.join(WS, "_analysis", "quality_proposal.tsv")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402
sys.stdout.reconfigure(encoding="utf-8")

CJK = re.compile(r"[\u4e00-\u9fa5]")


def keep_better(group):
    """同源重复里保留哪一份: 名字更像曲名的优先(CJK > ASCII; 无 `_2`/`&nbsp;` 等痕迹的优先),
    其次标签多的优先, 最后取文件名短的。"""
    def score(r):
        t = r.get("title") or ""
        s = 0
        s += 2 if CJK.search(t) else 0
        s -= 1 if re.search(r"[_&]|nbsp|_\d$", t) else 0
        s += min(len(r.get("usertag") or []), 3) * 0.1
        return (s, -len(r["file"][0]))
    return sorted(group, key=score, reverse=True)[0]


def move_out(fn, sub, why):
    dest = os.path.join(SUSPECT, sub)
    os.makedirs(dest, exist_ok=True)
    moved = []
    for suffix in ("", "_expand", "_buf"):
        for ext in (".txt", ".json"):
            p = os.path.join(SCORES, fn[:-4] + suffix + ext)
            if os.path.isfile(p):
                shutil.move(p, os.path.join(dest, os.path.basename(p)))
                moved.append(os.path.basename(p))
    return moved


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply-junk", action="store_true")
    ap.add_argument("--apply-dup", action="store_true")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    aj = a.apply_junk or a.apply
    ad = a.apply_dup or a.apply

    rows = [json.loads(l) for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8")]
    junk, suspect, groups = [], [], collections.defaultdict(list)
    for r in rows:
        sc = r.get("score") or ""
        seq = jptok.seq(sc)
        n = len(seq)
        groups[" ".join(sc.split())].append(r)
        if n < 20:
            continue
        c = collections.Counter(d for d, _x, _y in seq)
        top = c.most_common(1)[0][1]
        toks = len([t for t in sc.split() if t != "|"])
        ratio = n / max(1, toks)
        info = (r["file"][0], r.get("title") or "", n, round(top / n, 2), round(ratio, 2), len(c))
        if top / n >= 0.9 or ratio < 0.25 or (len(c) <= 2 and n >= 20):
            junk.append(info)
        elif top / n >= 0.5 or ratio < 0.35:
            suspect.append(info)

    same_src_dup, cross_dup = [], []
    for k, g in groups.items():
        if len(g) < 2:
            continue
        srcs = set((x.get("source") or [""])[0] for x in g)
        keep = keep_better(g)
        drop = [x for x in g if x is not keep]
        (same_src_dup if len(srcs) == 1 else cross_dup).append((keep, drop))

    print("=== 体检结果 (%d 首) ===" % len(rows))
    print("A 明确垃圾: %d 首" % len(junk))
    for fn, t, n, tp, rt, nd in sorted(junk, key=lambda x: -x[3])[:12]:
        print("    单音占比 %.2f · 音符/token %.2f · 音级 %d · %d 音  %s" % (tp, rt, nd, n, t[:20]))
    print("B 同源完全重复: %d 组 -> 可去掉 %d 份" % (len(same_src_dup), sum(len(d) for _k, d in same_src_dup)))
    for k, d in same_src_dup[:6]:
        print("    留 %-32s 去 %s" % (k["file"][0][:32], [x["file"][0][:26] for x in d]))
    print("C 可疑/跨站重复(只提案): %d 首可疑 + %d 组跨站重复"
          % (len(suspect), len(cross_dup)))

    with io.open(OUT, "w", encoding="utf-8", newline="\n") as g:
        g.write("kind\tfile\ttitle\tnotes\ttop_pitch_ratio\tnote_token_ratio\tn_pitches\tpeer\n")
        for fn, t, n, tp, rt, nd in suspect:
            g.write("suspect\t%s\t%s\t%d\t%.2f\t%.2f\t%d\t\n" % (fn, t, n, tp, rt, nd))
        for k, d in cross_dup:
            g.write("cross_dup_keep\t%s\t%s\t\t\t\t\t%s\n"
                    % (k["file"][0], k.get("title") or "", ",".join(x["file"][0] for x in d)))
            for x in d:
                g.write("cross_dup_drop\t%s\t%s\t\t\t\t\t%s\n" % (x["file"][0], x.get("title") or "", k["file"][0]))
    print("提案: %s" % OUT)

    if aj and junk:
        for fn, t, n, tp, rt, nd in junk:
            move_out(fn, "junk", "单音占比 %.2f / 音符token %.2f" % (tp, rt))
        with io.open(os.path.join(SUSPECT, "junk", "README.md"), "w", encoding="utf-8", newline="\n") as g:
            g.write("# junk —— 自动隔离的「转写失败」曲谱(只移不删)\n\n"
                    "判据(任一): 单音占比>=90% / 音符占 token<25% / 音级数<=2 且 >=20 音。\n"
                    "由 `jianpu2/tools/audit_corpus_quality.py --apply-junk` 移入, 时间 {t}。\n"
                    "要恢复: 移回 `../../scores/` 再跑 `parse_scores.py`。\n".format(t=time.strftime("%Y-%m-%d %H:%M")))
        print("已隔离 A: %d 首" % len(junk))
    if ad and same_src_dup:
        n = 0
        lines = ["# dup-identical —— 同源、整段 score 逐字相同的重复拷贝(只移不删)\n",
                 "保留规则: 名字更像曲名(CJK 优先, 无 `_2`/`&nbsp;` 痕迹) > 标签多 > 文件名短。\n",
                 "由 `jianpu2/tools/audit_corpus_quality.py --apply-dup` 移入, 时间 {t}。\n\n"
                 .format(t=time.strftime("%Y-%m-%d %H:%M"))]
        for k, d in same_src_dup:
            for x in d:
                move_out(x["file"][0], "dup-identical", "")
                lines.append("- 去掉 `%s`(%s) —— 与 `%s` 逐字相同, 同 source %s\n"
                             % (x["file"][0], x.get("title") or "", k["file"][0], (k.get("source") or [""])[0]))
                n += 1
        with io.open(os.path.join(SUSPECT, "dup-identical", "README.md"), "w", encoding="utf-8", newline="\n") as g:
            g.writelines(lines)
        print("已去重 B: %d 份" % n)
    if not (aj or ad):
        print("\n(加 --apply-junk / --apply-dup / --apply 才会真的移走)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
