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


def check_chord_sync(FB):
    """兜底类**必须**跟着唯一实现一起认和弦 token(否则 CI 会按旧口径改写 223 首)。

    为什么单独钉一下: CI(`.github/workflows/parse.yaml`)显式设 `JIANPU_ALLOW_FALLBACK_JTOK=1`,
    再 `git add -A` + 自动提交 —— 兜底与 jptok 漂了不是"红了就算", 是**真的会改写数据**。
    2026-09-28 那次 3044 首重复小节线就是这么来的。这里的用例是**抄 jptok 的实测口径**:
    每个和弦 token 要逐音给对(音级/变音/八度), 顺序照书写顺序。
    """
    cases = [
        ("64", [(6, 0, 0), (4, 0, 0)]),
        (",4,,b5,,3,,1", [(4, 0, 1), (5, -1, 2), (3, 0, 2), (1, 0, 2)]),   # 八度记号在各自音级左边
        ("q'16", [(1, 0, -1), (6, 0, 0)]),
        ("s6,5.", [(6, 0, 0), (5, 0, 1)]),
        ("64x0", [(6, 0, 0), (4, 0, 0), (None, 0, 0), (None, 0, 0)]),       # 和弦里有念白/休止
        ("0", [(None, 0, 0)]),
    ]
    bad = []
    for tok, want in cases:
        if not hasattr(FB, "parse_token_all"):
            bad.append((tok, want, "兜底类没有 parse_token_all"))
            continue
        got = FB.parse_token_all(tok)
        if got != want:
            bad.append((tok, want, got))
    return bad


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
            # ⚠ 2026-10-05: 拿 `parse_token_all` 比, **不再拿 `parse_token`** —— 和弦 token 在
            #   唯一实现那边返回**列表**(逐音), 而兜底类复刻它要再写一套和弦正则(就是"第三份口径")。
            #   `parse_token_all` 是两边的公共口径: 兜底类没有它就当场红(见下面 load_fallback 的说明)。
            for fn_name in ("is_note", "parse_token_all", "duration_letter", "beat"):
                x = getattr(jptok, fn_name)(t)
                y = getattr(FB, fn_name)(t)
                if x != y:
                    bad.setdefault(fn_name, []).append((fn, t, x, y))
        # ② seq(): 整份谱 -> 有音高的 token 解析结果(export_hf / audit_corpus_quality /
        #    quarantine_short_scores 都用它; 2026-09-24 兜底类**缺这个方法**导致 CI 挂过 ->
        #    现在逐首比, 以后谁少实现一个方法/口径漂了都会红)
        x = jptok.seq(body)
        y = FB.seq(body)
        if x != y:
            bad.setdefault("seq", []).append((fn, "", f"{len(x)} 音", f"{len(y)} 音"))

        # ③ 拍号
        x = jptok.beats_per_bar_from(text)
        y = FB.beats_per_bar_from(text)
        if x != y:
            bad.setdefault("beats_per_bar_from", []).append((fn, "", x, y))
        # ④ 小节恢复
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
