# -*- coding: utf-8 -*-
"""找**旋律克隆**：两首不同曲名的谱，旋律却几乎一样（同曲异名 / 重复转写 / 改编）。

**只读**，只出提案 TSV，不动语料。三个用途：
  1. 查重：同一首歌被转写两次、挂了两个曲名（语料里的"隐藏重复"）；
  2. 补标签：无标签的歌若与某首**已带标签**的歌旋律克隆，标签大概率可以借过来（提案，不自动写）；
  3. 认改编/器乐谱：旋律大面积重合但音区/节奏不同。

算法：把每首歌的（音高+八度）序列切成长度 K 的窗口建索引 -> 只在"跨歌共享窗口"的候选对里
算**最长公共子串(LCS)**（用 difflib 的滑动块，够快）-> 按 LCS 长度与覆盖率排序。

注意：旋律检索用的是音高序列（`lookup.pitch_and_oct`），所以这里也用它，保证与检索口径一致。

用法:
    python3 tools/audit_melody_clones.py                       # 默认 K=14, LCS>=24 且覆盖率>=0.3
    python3 tools/audit_melody_clones.py --out _analysis/旋律克隆提案.tsv
"""
import argparse
import collections
import difflib
import io
import re
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.path.join(ROOT, "skills", "jianpu-melody-lookup")
for p in (SKILL, DB):
    if p not in sys.path:
        sys.path.insert(0, p)
from lookup import pitch_and_oct          # noqa: E402  **与检索同一口径**
from eval_golden import norm, same        # noqa: E402  曲名口径也复用同一份

GARBLED = re.compile(r"^[\W_]{0,2}$|^[\u4e00-\u9fa5A-Za-z0-9]{1,2}$")   # 一两个字/下划线拼的残名


def song_seq(r):
    """整首歌的音高序列（分段拼起来）。"""
    out = []
    for sec in r.get("sections") or []:
        p, _ = pitch_and_oct(sec.get("score"))
        out.append(p)
    return "".join(out)


def same_title_report(rows, a):
    """同名组内两两比旋律 —— 目的是把"**同名但其实是两首歌**"挑出来。

    为什么值得单做: `group_of(title)` 只按**曲名**归组(检索的"按曲名找"、榜单的"多版本留一"
    分母都靠它)。可语料里有大量**通用曲名**：《爱》6 个版本、《家》5 个、《谁》6 个 ——
    它们大概率是**不同的歌恰好同名**, 而不是"同一首的多个版本"。这样归组会把 A 歌的版本
    算成 B 歌的多版本, 榜单的"多版本留一"分母与"按曲名找"的结果都会被带偏。
    """
    from eval_golden import norm                     # 同一份曲名口径
    groups = collections.defaultdict(list)
    for r in rows:
        seq = song_seq(r)
        if len(seq) < 11:
            continue
        title = r.get("title") or ""
        groups[norm(title)].append({"title": title, "seq": seq,
                                    "file": (r.get("file") or [""])[0] if isinstance(r.get("file"), list) else r.get("file")})

    def lcs(x, y):
        return difflib.SequenceMatcher(None, x, y, autojunk=False).find_longest_match(0, len(x), 0, len(y)).size

    out = ["曲名组\t版本数\t疑似不同曲的对\t最像的一对(相似度)\t最不像的一对(相似度)\t文件列表"]
    mixed, allsame, alldiff = 0, 0, 0
    detail = []
    for key, vs in groups.items():
        if len(vs) < 2:
            continue
        best = (-1, None, None)
        worst = (2, None, None)
        diff_pairs = 0
        for i in range(len(vs)):
            for j in range(i + 1, len(vs)):
                A, B = vs[i], vs[j]
                n = lcs(A["seq"], B["seq"])
                cov = n / max(1, min(len(A["seq"]), len(B["seq"])))
                if cov > best[0]:
                    best = (cov, A, B)
                if cov < worst[0]:
                    worst = (cov, A, B)
                if cov < 0.35:
                    diff_pairs += 1
        if diff_pairs == 0:
            allsame += 1
        elif diff_pairs == len(vs) * (len(vs) - 1) // 2:
            alldiff += 1
        else:
            mixed += 1
        if diff_pairs:
            detail.append((diff_pairs, worst[0], vs, best[0]))
            out.append("\t".join([
                vs[0]["title"], str(len(vs)), str(diff_pairs),
                f"{best[1]['title'][:14]}({best[0]:.0%})",
                f"{worst[1]['title'][:14]}({worst[0]:.0%})",
                " | ".join(f"{v['file']}" for v in vs)]))

    print(f"同名组(>=2 个版本) {sum(1 for v in groups.values() if len(v) > 1)} 个:")
    print(f"  **所有两两都像**(确实是同一首的多版本): {allsame}")
    print(f"  **所有两两都不像**(更像是不同的歌恰好同名): {alldiff}")
    print(f"  混合(部分像部分不像): {mixed}")
    detail.sort(key=lambda x: (-x[0], x[1]))
    print("\n差异最大的组(前 20):")
    for diff_pairs, w, vs, b in detail[:20]:
        print(f"  「{vs[0]['title'][:18]}」{len(vs)} 个版本, {diff_pairs} 对不像 "
              f"(最像 {b:.0%} / 最不像 {w:.0%})")
    out_path = a.out or os.path.join(os.path.dirname(ROOT), "_analysis", "同名不同曲提案.tsv")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    io.open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"\n明细 -> {out_path}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--k", type=int, default=14, help="窗口长度(建索引用)")
    ap.add_argument("--min-lcs", type=int, default=24, help="最短公共子串(低于此不算克隆)")
    ap.add_argument("--min-cov", type=float, default=0.30, help="LCS 占较短那首的比例下限")
    ap.add_argument("--out", default="")
    ap.add_argument("--same-title", action="store_true",
                    help="换一件事做: 只看**同名**的歌两两之间旋律像不像, 找「同名不同曲」")
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    if a.same_title:
        return same_title_report(rows, a)
    songs = []
    for r in rows:
        seq = song_seq(r)
        if len(seq) < 11:
            continue
        songs.append({"file": (r.get("file") or [""])[0] if isinstance(r.get("file"), list) else r.get("file"),
                      "title": r.get("title") or "",
                      "tags": (r.get("tag") or []) + (r.get("usertag") or []),
                      "seq": seq})
    print(f"曲 {len(songs)} 首, 总音数 {sum(len(s['seq']) for s in songs)}")

    # 窗口索引: 窗口 -> 出现过的歌
    idx = collections.defaultdict(set)
    K = a.k
    for i, s in enumerate(songs):
        q = s["seq"]
        for j in range(0, len(q) - K + 1):
            idx[q[j:j + K]].add(i)
    cand = collections.Counter()
    for w, ids in idx.items():
        if len(ids) < 2:
            continue
        ids = sorted(ids)
        for x in range(len(ids)):
            for y in range(x + 1, len(ids)):
                cand[(ids[x], ids[y])] += 1
    print(f"共享 {K} 音窗口的候选对: {len(cand)}")

    def lcs(x, y):
        sm = difflib.SequenceMatcher(None, x, y, autojunk=False)
        m = sm.find_longest_match(0, len(x), 0, len(y))
        return m.size

    def classify(A, B, n):
        """给这一对一个人能直接照着做的判定。"""
        A, B = dict(A), dict(B)
        ta, tb = A["title"], B["title"]
        la, lb = len(A["seq"]), len(B["seq"])
        if same(norm(ta), norm(tb)):
            return "同名多版本", "预期内(榜单的多版本留一就是这种); 不用动"
        if n >= 0.9 * min(la, lb):          # 短的那首几乎被完全包含 -> 同一首的两个文件
            # 借标签**必须**建立在"同一首"上: 只有这一类才允许建议借标签(2026-09-24 修正:
            # 原来把 30% 覆盖率的重合也算"可借", 结果把《泼水歌》的"儿歌"借给了《大白鹅》、
            # 把《红树林之歌》的歌手借给了《红树林》—— 那些只是**共享乐句的不同歌**)。
            if not A["tags"] and B["tags"]:
                return "标签-可借", f"同一首的另一个转写已有标签, 可借: {'/'.join(B['tags'][:3])}"
            if not B["tags"] and A["tags"]:
                return "标签-可借", f"同一首的另一个转写已有标签, 可借: {'/'.join(A['tags'][:3])}"
            if ta.startswith("未命名") or tb.startswith("未命名"):
                other = tb if ta.startswith("未命名") else ta
                return "标题-未命名", f"按对侧曲名起名(疑似同一首的两个转写): {other[:20]}"
            if GARBLED.match(ta.strip()) or GARBLED.match(tb.strip()):
                other = tb if GARBLED.match(ta.strip()) else ta
                return "标题-残名", f"残名/截断, 对侧更完整: {other[:20]}"
            return "重复-异名", "疑似同一份转写挂了两个名字 -> 人工判: 合并/隔离其一"
        if not A["tags"] and B["tags"]:
            return "共用曲调/改编", f"只部分重合(不是同一首的充分证据); 若确认同曲再考虑借标签: {'/'.join(B['tags'][:3])}"
        if not B["tags"] and A["tags"]:
            return "共用曲调/改编", f"只部分重合(不是同一首的充分证据); 若确认同曲再考虑借标签: {'/'.join(A['tags'][:3])}"
        return "共用曲调/改编", "只部分重合: 可能是改编/片段/共用同一曲调, 人工看一眼"

    out = ["类别\t文件A\t曲名A\t标签A\t文件B\t曲名B\t标签B\t公共音数\t覆盖率(较短)\t长度A\t长度B\t建议"]
    hits = []
    for (i, j), nwin in cand.most_common():
        A, B = songs[i], songs[j]
        if nwin * 2 < a.min_lcs:              # 窗口数远小于阈值 -> LCS 不可能够长
            continue
        n = lcs(A["seq"], B["seq"])
        cov = n / max(1, min(len(A["seq"]), len(B["seq"])))
        if n >= a.min_lcs and cov >= a.min_cov:
            hits.append((n, cov, A, B))
    hits.sort(key=lambda x: (-x[1], -x[0]))
    kinds = collections.Counter()
    for n, cov, A, B in hits:
        kind, advice = classify(A, B, n)
        kinds[kind] += 1
        out.append(f"{kind}\t{A['file']}\t{A['title']}\t{'|'.join(A['tags'])}\t{B['file']}\t{B['title']}\t"
                   f"{'|'.join(B['tags'])}\t{n}\t{cov:.2f}\t{len(A['seq'])}\t{len(B['seq'])}\t{advice}")

    print(f"\n判定为克隆/高度重合的对: {len(hits)}")
    for n, cov, A, B in hits[:25]:
        ta = "/".join(A["tags"][:2]) or "(无标签)"
        tb = "/".join(B["tags"][:2]) or "(无标签)"
        print(f"  {n:>4} 音 覆盖 {cov:.0%}  「{A['title'][:18]}」({ta})  <->  「{B['title'][:18]}」({tb})")

    print("\n按可执行性分类:")
    for k, v in kinds.most_common():
        print(f"    {k:12s} {v}")

    out_path = a.out or os.path.join(os.path.dirname(ROOT), "_analysis", "旋律克隆提案.tsv")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    io.open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print(f"\n明细 -> {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
