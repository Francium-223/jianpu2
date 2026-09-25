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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

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
        rows.append((r["file"][0], cur, new, kind, conf))

    with io.open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("file\tcurrent_title\tproposed_title\tkind\taccepted\n")
        for fn, cur, new, kind, conf in rows:
            g.write("\t".join([fn, cur, new, kind, conf]) + "\n")

    hi = sum(1 for x in rows if x[4] == "1")
    print("括号不配对的曲名: %d 首" % n_unbal)
    print("出提案: %d 条 (其中 confidence=1 的 %d 条)" % (len(rows), hi))
    for kind in ("未闭合开括号", "多余闭括号"):
        n = sum(1 for x in rows if x[3] == kind)
        h = sum(1 for x in rows if x[3] == kind and x[4] == "1")
        print("   %-8s %3d 条 (高置信 %d)" % (kind, n, h))
    print("-> %s" % a.out)
    print("(只出提案, 没有改任何语料; 要落地得先人工过一遍 accepted 列)")
    return 0


if __name__ == "__main__":
    if any(x in ("-h", "--help") for x in sys.argv[1:]):
        print(__doc__)
        raise SystemExit(0)
    sys.exit(main())
