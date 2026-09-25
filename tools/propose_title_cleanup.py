#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给**括号/标点不配对**的曲名出清理提案（只写 TSV，绝不动语料）。

背景（2026-09-25 审计）: 全库 7,318 首里有 **209 首**曲名括号不配对，绝大多数长这样：

    一切刚刚好（李健        世界末日（         The Sound of Silence（
    Danny Boy（小野丽莎     OVER THE RAINBOW）

成因和"尾部悬挂分隔符"是同一件事：早前某版解析把歌手/注解用括号拼进曲名，后来不拼了，
于是留下半个括号（或只剩闭括号）。**注意这批几乎都没有 `artist=`**，
所以不能像那 40 首那样"用 artist 字段自证"——只能靠曲名自身的形状判断，
因此本工具**只出提案不落地**，由人过一遍再改。

判定（用括号配对扫描，不靠正则猜）:
  * `未闭合开括号`：`（` 从头到尾没等到 `）` -> 从**第一个**未闭合的开括号起截断。
    若截断下来的那段**不含标点且不超过 12 字**，多半就是歌手/注解 -> confidence=1；
    否则（像是被截断的正题，如 `ドラマ「アンナチュラ`）-> confidence=0，交人看。
  * `多余闭括号`：`）` 没有对应的开括号 -> 直接去掉那个闭括号。

用法:
    python3 tools/propose_title_cleanup.py                  # 写到 _analysis/title_bracket_proposal.tsv
    python3 tools/propose_title_cleanup.py --out /tmp/x.tsv
"""
import argparse
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from safeout import default_out                       # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
OUT = default_out(DB, "title_bracket_proposal.tsv")

PAIRS = [("（", "）"), ("(", ")"), ("【", "】"), ("《", "》"), ("「", "」")]
_OPEN = {o for o, _ in PAIRS}
_CLOSE = {c for _, c in PAIRS}
_PUNCT = re.compile(r"[，。、；：！？…—·,.;:!?\"'“”‘’（）()【】《》\[\]]")


def first_unbalanced(t):
    """返回 ('open', 下标) / ('close', 下标) / None —— 第一个让括号失配的位置。"""
    stack = []
    for i, ch in enumerate(t):
        if ch in _OPEN:
            stack.append(i)
        elif ch in _CLOSE:
            if not stack:
                return ("close", i)
            stack.pop()
    return ("open", stack[0]) if stack else None


def propose(title):
    """-> (kind, 新曲名, confidence) ; 不改动则 kind=''。"""
    t = (title or "").strip()
    if not t:
        return "", "", "0"
    bad = first_unbalanced(t)
    if not bad:
        return "", "", "0"
    kind, i = bad
    if kind == "close":
        new = (t[:i] + t[i + 1:]).strip(" \u3000")
        # `难忘的爱人】彩谱】` 这种有**多个**多余闭括号: 只去掉一个会留下 `…彩谱】` 这种半成品,
        # 越看越像另一条错题。整条标 0 交人看, 别提出半成品。
        if first_unbalanced(new) is not None:
            return ("多余闭括号(多个)", new, "0")
        return ("多余闭括号", new, "1" if new else "0")
    tail = t[i + 1:].strip(" \u3000")
    core = t[:i].strip(" \u3000_-")
    if not core:
        return "", "", "0"                     # 整条就是个括号, 不敢动
    # 截下来的那段像不像"歌手/注解": 短、无标点
    looks_like_artist = bool(tail) and len(tail) <= 12 and not _PUNCT.search(tail)
    bare = not tail                            # `世界末日（` 这种只剩个开括号
    conf = "1" if (bare or looks_like_artist) else "0"
    return ("未闭合开括号", core, conf)


def clean_page(ptitle):
    """原谱站页面标题 -> 去掉站点尾巴, 用作**独立佐证**(与 refine_titles_from_pages 同口径)。"""
    t = re.sub(r"\s+", " ", ptitle or "").strip()
    t = re.sub(r"\s*(歌谱简谱网|简谱之家|中国曲谱网|免费下载).*$", "", t).strip()
    return t.split("_")[0].strip()


def corroborated(new, page_title):
    """页面标题能不能佐证这个新曲名(归一化后**以它开头**)。

    2026-09-25: 一开始写的是"包含", 结果把 `…_ドラマ「アンナチュラ` 砍成 `…_ドラマ` 也算通过 ——
    页面标题确实**包含**它, 但那是把日本原题截断了, 不是我们要的。改成必须**开头**才算。
    """
    n, p = _norm(new), _norm(clean_page(page_title))
    return bool(n) and p.startswith(n)


def _norm(s):
    return re.sub(r"[\s\-_·、,，。.（）()【】\[\]《》!！？?：:；；'\"“”‘’~～|/\\+&]", "",
                  (s or "")).casefold()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--pages", default=os.path.join(DB, "source_pages.json"),
                    help="原谱页表, 用来给提案找**独立佐证**(页面标题)")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--plan", action="store_true", help="只打印改名计划")
    ap.add_argument("--apply", action="store_true", help="按 accepted=1 落地(改名 + 同步首行)")
    a = ap.parse_args()

    sp = {}
    if os.path.isfile(a.pages):
        sp = json.load(io.open(a.pages, encoding="utf-8"))

    rows = []
    n_unbal = 0
    for line in io.open(a.data, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        cur = (r.get("title") or "").strip()
        if first_unbalanced(cur) is None:
            continue
        n_unbal += 1
        kind, new, conf = propose(cur)
        if not new or new == cur:
            continue
        s = r.get("source") or []
        s = s[0] if isinstance(s, list) and s else (s if isinstance(s, str) else "")
        pt = (sp.get(s) or {}).get("t", "") if s else ""
        corr = corroborated(new, pt)
        # 只有**页面标题佐证** 且 形状干净(已平衡) 才敢标 1: 这批没有 artist= 可自证
        acc = "1" if (conf == "1" and corr and first_unbalanced(new) is None) else "0"
        rows.append((r["file"][0], cur, new, kind, acc, ("1" if corr else "0"), clean_page(pt)[:80]))

    with io.open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("file\tcurrent_title\tproposed_title\tkind\taccepted\tcorrob\tpage_title\n")
        for fn, cur, new, kind, acc, corr, pt in rows:
            g.write("\t".join([fn, cur, new, kind, acc, corr, pt]) + "\n")

    hi = sum(1 for x in rows if x[4] == "1")
    cor = sum(1 for x in rows if x[5] == "1")
    print("括号不配对的曲名: %d 首" % n_unbal)
    print("出提案: %d 条" % len(rows))
    print("   页面标题能佐证: %d 条" % cor)
    print("   佐证 + 形状干净 -> accepted=1: %d 条" % hi)
    for kind in sorted({x[3] for x in rows}):
        n = sum(1 for x in rows if x[3] == kind)
        h = sum(1 for x in rows if x[3] == kind and x[4] == "1")
        print("   %-14s %3d 条 (accepted=1 %d)" % (kind, n, h))
    print("-> %s" % a.out)
    if not (a.apply or a.plan):
        print("(只出提案, 没有改任何语料; 要看计划加 --plan, 要落地加 --apply)")
        return 0

    # ---- 落地: 复用 refine_titles_from_pages 的改名机器(冲突规则 + 首行 `%<名>` 同步) ----
    import refine_titles_from_pages as R          # noqa: E402
    todo = [(fn, cur, new) for fn, cur, new, _k, acc, _c, _pt in rows if acc == "1"]
    os.makedirs(R.SCORES, exist_ok=True)
    if a.plan:
        print("\n改名计划(%d 首; 只打印):" % len(todo))
        taken = set()
        for fn, cur, new in todo:
            tgt = R.pick_target(fn, new, taken)
            taken.add(tgt)
            print("  %-44s -> %-38s  title=%s" % (fn[:44], tgt[:38], new))
        return 0

    n = 0
    taken = set()
    for fn, cur, new in todo:
        p = os.path.join(R.SCORES, fn)
        if not os.path.isfile(p):
            continue
        new = R.clean_title(new)
        if not new:
            continue
        raw = open(p, "rb").read()
        text = raw.decode("utf-8")
        text = re.sub(r"(?m)^title=.*$", lambda m: "title=" + new, text, count=1)
        text = re.sub(r"\n{3,}", "\n\n", text)
        tgt = R.pick_target(fn, new, taken)
        taken.add(tgt)
        if tgt != fn:                              # 首行 `%<本文件名>` 必须跟着改(带扩展名!)
            head, newhead = "%" + fn, "%" + tgt
            for nl in ("\r\n", "\n"):
                if text.startswith(head + nl):
                    text = newhead + text[len(head):]
                    break
        open(p, "wb").write(text.encode("utf-8"))
        if tgt != fn:
            os.rename(p, os.path.join(R.SCORES, tgt))
        n += 1
    print("已按 accepted=1 改名 %d 首。记得跑 parse_scores.py 重建索引。" % n)
    return 0


if __name__ == "__main__":
    if any(x in ("-h", "--help") for x in sys.argv[1:]):
        print(__doc__)
        raise SystemExit(0)
    sys.exit(main())
