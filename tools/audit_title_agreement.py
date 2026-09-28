# -*- coding: utf-8 -*-
"""**同名不同源**的两份转写对不对得上？—— 用"两个独立转写互相验证"给转写错误率定量。

为什么做这个: 之前只肉眼看了 4 首, 说不出错误率。而语料里很多歌有**多个来源**各转了一份,
它们是**互相独立的转写** —— 两份旋律大面积对不上, 至少有一份是错的。
这不需要 GPU、不需要重跑模型, 是一份诚实的**下界**证据。

口径: 音高序列用 `lookup.pitch_and_oct`(与检索同一口径, 丢 0/x、丢八度),
相似度用 `difflib.SequenceMatcher.ratio()`(最长公共子序列型, 对插入/漏音敏感)。
注意局限(别过度解读): 不同源可能转的是**不同段落/不同编配**(器乐版、副歌起头),
所以"对不上"是**嫌疑**不是判决; 但"对得上"是很强的正确性证据。

用法:
    py -3.13 tools/audit_title_agreement.py
    py -3.13 tools/audit_title_agreement.py --out D:\\Documents_D\\_analysis\\同名异源一致性.tsv
"""
import argparse
import collections
import difflib
import io
import json
import os
import re
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.path.join(ROOT, "skills", "jianpu-melody-lookup")
for p in (SKILL, DB):
    if p not in sys.path:
        sys.path.insert(0, p)
from lookup import pitch_and_oct          # noqa: E402  与检索同一口径
from eval_golden import norm              # noqa: E402  曲名口径复用同一份

GARBLED = re.compile(r"^[\W_]{0,2}$|^[\u4e00-\u9fa5A-Za-z0-9]{1,2}$")


def best_shift_lcs(s1, s2):
    """把 s2 的唱名整体移 k 级(k=0..6)后最长的公共连续段 —— 用来区分"两首歌"和"同一首歌转调写的"。

    为什么要这一列: 简谱的 1-7 是**相对主音**的唱名, 同一首歌若一个源按 C 调记、另一个按关系小调/
    别的调记(实测很常见), 数字串会整体偏移 —— 直接比会看成"完全不同的歌"。
    """
    best, bk = 0, 0
    for k in range(7):
        t = "".join(str((int(c) - 1 + k) % 7 + 1) for c in s2)
        m = difflib.SequenceMatcher(None, s1, t, autojunk=False).find_longest_match(0, len(s1), 0, len(t))
        if m.size > best:
            best, bk = m.size, k
    return best, bk


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--out", default=r"D:\Documents_D\_analysis\同名异源一致性.tsv")
    ap.add_argument("--min-notes", type=int, default=20, help="两份都至少这么多音才比")
    ap.add_argument("--top", type=int, default=25)
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    print(f"语料 {len(rows)} 首")

    def notes(r):
        return pitch_and_oct(r.get("score") or "")[0]

    groups = collections.defaultdict(list)
    for r in rows:
        t = norm(r.get("title") or "")
        if not t or GARBLED.match(t):
            continue
        seq = notes(r)
        if len(seq) < a.min_notes:
            continue
        src = r.get("source") or ""
        src = src[0] if isinstance(src, list) else src
        groups[t].append({"seq": seq, "src": src, "file": (r.get("file") or [""])[0],
                          "status": r.get("status") or ""})

    multi = {t: v for t, v in groups.items() if len({x["src"] for x in v}) >= 2}
    print(f"同名组 {len(groups)} 个; 其中**含至少两个不同源**的 {len(multi)} 组")

    pairs = []
    for t, v in multi.items():
        for i in range(len(v)):
            for j in range(i + 1, len(v)):
                if v[i]["src"] == v[j]["src"]:
                    continue
                s1, s2 = v[i]["seq"], v[j]["seq"]
                # 老老实实算真值: 长序列上 quick_ratio 只是**上界**, 拿上界分档会自欺(见项目里"别猜数字"的口径)。
                sm = difflib.SequenceMatcher(None, s1, s2, autojunk=False)
                ratio = sm.ratio()
                # 整串相似度会被"同名不同歌/不同段落"拉垮, 所以再算**最长公共连续段**(LCS 块):
                # 同一首歌的两份独立转写, 总会有一大段逐音相同的旋律; 不同歌基本没有。
                blk = sm.find_longest_match(0, len(s1), 0, len(s2))
                lcs = blk.size
                pairs.append({"title": t, "ratio": round(ratio, 3), "lcs": lcs,
                              "cov": round(lcs / float(min(len(s1), len(s2)) or 1), 3),
                              "n1": len(s1), "n2": len(s2), "seq1": s1, "seq2": s2,
                              "f1": v[i]["file"], "f2": v[j]["file"],
                              "s1": v[i]["src"], "s2": v[j]["src"]})
    print(f"跨源配对数 {len(pairs)}")
    if not pairs:
        return

    buckets = collections.Counter()
    for p in pairs:
        r = p["ratio"]
        buckets["=1.000 完全相同" if r >= 0.999 else
                ">=0.95 几乎相同" if r >= 0.95 else
                "0.80~0.95 大体相同" if r >= 0.80 else
                "0.60~0.80 明显不同" if r >= 0.60 else
                "<0.60 基本对不上"] += 1
    print()
    print("整串相似度分布(会被'同名不同歌'拉垮):")
    for k in ("=1.000 完全相同", ">=0.95 几乎相同", "0.80~0.95 大体相同",
              "0.60~0.80 明显不同", "<0.60 基本对不上"):
        n = buckets.get(k, 0)
        print(f"   {k:<22} {n:>5}  ({n * 100.0 / len(pairs):.1f}%)")

    lc = collections.Counter()
    for p in pairs:
        L = p["lcs"]
        lc["LCS>=48 一大段逐音相同" if L >= 48 else
           "LCS 24~47" if L >= 24 else
           "LCS 12~23" if L >= 12 else
           "LCS <12 几乎没有相同的连续段"] += 1
    print()
    print("最长公共连续段(LCS 块)分布 —— **同一首歌的两份独立转写总该有一大段逐音相同**:")
    for k in ("LCS>=48 一大段逐音相同", "LCS 24~47", "LCS 12~23", "LCS <12 几乎没有相同的连续段"):
        n = lc.get(k, 0)
        print(f"   {k:<32} {n:>5}  ({n * 100.0 / len(pairs):.1f}%)")

    strong = [p for p in pairs if p["lcs"] < 24]
    print()
    print(f"原调下没有长公共段(<24)的 {len(strong)} 对 -> 再按'整体移调'比一遍(区分'不同歌'与'同曲异调')")
    for p in strong:
        p["lcs_shift"], p["shift"] = best_shift_lcs(p["seq1"], p["seq2"])
    same_key = [p for p in strong if (p["lcs_shift"] or 0) >= 24]
    other = [p for p in strong if (p["lcs_shift"] or 0) < 24]
    print(f"   同曲但**整体移调**记的: {len(same_key)} 对(原调比 LCS<24, 移调后 >=24)")
    for p in sorted(same_key, key=lambda x: -x["lcs_shift"])[:a.top]:
        print(f"   移 {p['shift']} 级 LCS {p['lcs_shift']:>3}  {p['title'][:18]:<20} "
              f"{p['n1']:>4}音 {p['s1'][:13]:<15} {p['f1'][:26]:<28} vs "
              f"{p['n2']:>4}音 {p['s2'][:13]:<15} {p['f2'][:26]}")
    print(f"   移调后仍对不上的: {len(other)} 对(不同歌/不同段落/转写错)")
    for p in other[:a.top]:
        print(f"   LCS {p['lcs']:>3} 移调后 {(p['lcs_shift'] or 0):>3}  {p['title'][:16]:<18} "
              f"{p['n1']:>4}音 {p['s1'][:13]:<15} {p['f1'][:24]:<26} vs "
              f"{p['n2']:>4}音 {p['s2'][:13]:<15} {p['f2'][:24]}")

    with io.open(a.out, "w", encoding="utf-8") as g:
        g.write("lcs\tlcs_shift\tshift\tratio\tcov\ttitle\tnotes_a\tsource_a\tfile_a\tnotes_b\tsource_b\tfile_b\n")
        for p in sorted(pairs, key=lambda x: (x.get("lcs_shift") or x["lcs"], x["lcs"])):
            g.write(f"{p['lcs']}\t{p.get('lcs_shift', '')}\t{p.get('shift', '')}\t{p['ratio']}\t{p['cov']}\t"
                    f"{p['title']}\t{p['n1']}\t{p['s1']}\t{p['f1']}\t{p['n2']}\t{p['s2']}\t{p['f2']}\n")
    print()
    print(f"全部 {len(pairs)} 对 -> {a.out}")


if __name__ == "__main__":
    main()
