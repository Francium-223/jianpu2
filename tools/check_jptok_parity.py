# -*- coding: utf-8 -*-
"""**两份 jptok 口径的等价性测试** —— 把"必须同步"变成"每次都被证明"。

背景：简谱 token 的唯一实现在 `jianpu2/skills/jianpu-melody-lookup/jptok.py`；`score.py` 里还留着
一份**兜底** `_FallbackJptok`（给没有 jianpu2 的环境用）。2026-09-23 这两份**一起漂了**：
正则只认前缀时值、后缀形（`6c.`/`5s`/`3q`）被静默丢掉，36 首受损，很久才发现。

既然不能（或不想）删掉兜底，就把它变成**有测试的**：拿全语料的每一个 token 去问两边，
`is_note / parse_token / duration_letter / beat` 必须完全一致；再用同一份分段调
`recover_bars`，小节位置也必须一致。任何一处不一致 -> 退非 0 并打印例子。

兜底类的取法：用 `ast` 从 `score.py` 源码里**原样抽出** `_FallbackJptok`（它只在
"jptok 找不到"的分支里定义，正常 import 拿不到），`textwrap.dedent` 后 exec。

用法:
    python3 tools/check_jptok_parity.py            # 扫全部 scores/*.txt
    python3 tools/check_jptok_parity.py --limit 200
"""
import argparse
import ast
import io
import os
import re
import sys
import textwrap

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.environ.get("JIANPU_JTOK") or os.path.join(ROOT, "skills", "jianpu-melody-lookup")
if os.path.isdir(SKILL) and SKILL not in sys.path:
    sys.path.insert(0, SKILL)
import jptok                                   # noqa: E402  **唯一实现**


def load_fallback():
    src = io.open(os.path.join(DB, "score.py"), encoding="utf-8").read()
    tree = ast.parse(src)
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef) and node.name == "_FallbackJptok":
            body = textwrap.dedent(ast.get_source_segment(src, node))
            ns = {"re": re, "os": os}
            exec(compile(body, "<fallback>", "exec"), ns)
            return ns["_FallbackJptok"]
    raise SystemExit("score.py 里找不到 _FallbackJptok（兜底被删了？那就把本测试也删掉）")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scores", default=os.path.join(DB, "scores"))
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    FB = load_fallback()
    print(f"jptok = {jptok.__file__}")
    print(f"兜底  = score.py:_FallbackJptok（ast 抽取）\n")

    files = sorted(f for f in os.listdir(a.scores)
                   if f.endswith(".txt") and not f.endswith(("_expand.txt", "_buf.txt")))
    if a.limit:
        files = files[:a.limit]
    bad = {}
    n_tok = n_file = 0
    for fn in files:
        raw = io.open(os.path.join(a.scores, fn), encoding="utf-8", errors="replace").read()
        head, sep, body = raw.partition("%--")
        text = head + sep + body
        # ① 逐 token 的四个函数
        for t in body.split():
            n_tok += 1
            for fn_name in ("is_note", "parse_token", "duration_letter", "beat"):
                x = getattr(jptok, fn_name)(t)
                y = getattr(FB, fn_name)(t)
                if x != y:
                    bad.setdefault(fn_name, []).append((fn, t, x, y))
        # ② 拍号
        x = jptok.beats_per_bar_from(text)
        y = FB.beats_per_bar_from(text)
        if x != y:
            bad.setdefault("beats_per_bar_from", []).append((fn, "", x, y))
        # ③ 小节恢复
        secs = [{"subtitle": "score", "score": " ".join(body.replace("%END", "").split())}]
        x = jptok.recover_bars(secs, x, keep_explicit=True)
        y = FB.recover_bars(secs, y, keep_explicit=True)
        if x != y:
            diff = [(i, p, q) for i, (p, q) in enumerate(zip(x, y)) if p != q][:3]
            bad.setdefault("recover_bars", []).append((fn, "", f"{len(x)} 小节", f"{len(y)} 小节 首个差异 {diff}"))
        n_file += 1
        if n_file % 2000 == 0:
            print(f"  ...已比 {n_file} 份")

    print(f"比过 {n_file} 份谱 / {n_tok} 个 token")
    if not bad:
        print("\njptok 与兜底 **逐项一致** ✓（这份测试以后就是那道「必须同步」的锁）")
        return 0
    print("\n!! 两份口径不一致（这正是 2026-09-23 那类事故的苗头）:")
    for k, v in bad.items():
        print(f"  {k}: {len(v)} 处")
        for row in v[:5]:
            print("     ", row)
    return 1


if __name__ == "__main__":
    sys.exit(main())
