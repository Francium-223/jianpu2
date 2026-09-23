# -*- coding: utf-8 -*-
"""解析曲谱的**副作用**自检 —— 别让"读一份谱"顺手改掉仓库。

为什么需要: score.py 的 parse() 不是只读的, 它会
  1. write_buf()/move_buf()  —— 用规范化后的内容**重写曲谱文件**(+同名 .json);
  2. make_link()            —— 生成/改 `by_*` 链接树(相对**当前目录**)。
于是"解析一份临时副本"曾经把已提交的 `by_status/ok/th10_06.txt` 改指到
`../../../../../../tmp/injtest5/th10_06.txt`(2026-09-24 实测), 整棵 by_* 树被污染。
另外 `parse_scores.py` 从别的目录跑会崩在 `FileNotFoundError: 'tags.json'`。

本脚本验四件事:
  A. 解析**仓库外**的副本 -> 仓库(git status)一点没变;
  B. 解析**语料内**的一份谱 -> 不该产生 diff(说明规范化是幂等的, CI 不会莫名多出改动);
  C. 从**别的目录**跑 `parse_scores.py --dry`(? 见下)不该因为 tags.json 崩;
     (这里用 `schema.load_tag_rules()` 直接验: cwd=/ 时也能读到 tags.json)
  D. `by_*` 链接树仍然指向 `scores/`(没有指向仓库外的死链/污染)。

用法: python3 tools/check_sideeffects.py
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.environ.get("JIANPU_JTOK") or os.path.join(ROOT, "skills", "jianpu-melody-lookup")
if os.path.isdir(SKILL) and SKILL not in sys.path:
    sys.path.insert(0, SKILL)

fails = []


def ok(cond, msg):
    print(("✓ " if cond else "✗ ") + msg)
    if not cond:
        fails.append(msg)


def status(d=None):
    return subprocess.run(["git", "status", "--porcelain"], cwd=d or DB,
                          capture_output=True, text=True).stdout


def main():
    if not os.path.isdir(os.path.join(DB, "scores")):
        sys.exit(f"没有语料: {DB}/scores (用 JIANPU_DB 指一下)")
    os.chdir(DB)                                  # 与 parse_scores.py 同样的前提
    sys.path.insert(0, DB)
    import score                                  # noqa: E402  (必须在 chdir 之后)

    # ---- A. 解析仓库外的副本 ----
    tmp = tempfile.mkdtemp(prefix="jpside-")
    sample = next((n for n in ("th10_06.txt", "义勇军进行曲.txt")
                   if os.path.isfile(os.path.join("scores", n))), None)
    if sample is None:
        sample = sorted(n for n in os.listdir("scores") if n.endswith(".txt"))[0]
    shutil.copyfile(os.path.join("scores", sample), os.path.join(tmp, sample))
    before = status()
    score.Score(os.path.join(tmp, sample)).parse()
    after = status()
    ok(before == after, "A. 解析仓库外的副本后, git status 没变(by_* 未被污染)")
    ok(os.path.isfile(os.path.join(tmp, os.path.splitext(sample)[0] + ".json")),
       "A. 副本自己的 .json 正常生成(说明 parse 本身没被护栏挡住)")

    # ---- B. 解析语料内的一份谱, 不该产生 diff(规范化幂等) ----
    b0 = status()
    score.Score(os.path.join("scores", sample)).parse()
    b1 = status()
    ok(b0 == b1, "B. 解析语料内的一份谱后 git status 没变(规范化是幂等的)")

    # ---- C. 换个目录也能读到 tags.json(单一真源按模块目录解析) ----
    cwd = os.getcwd()
    try:
        os.chdir("/")
        import schema
        try:
            rules = schema.load_tag_rules()
            ok(bool(rules[0]) or bool(rules[1]), "C. cwd=/ 时 schema.load_tag_rules() 仍能读到 tags.json")
        except FileNotFoundError as e:
            ok(False, f"C. cwd=/ 时读不到 tags.json: {e}")
    finally:
        os.chdir(cwd)

    # ---- D. by_* 树里没有指向仓库外的链接 ----
    bad = []
    n = 0
    for d in sorted(os.listdir(".")):
        if not d.startswith("by_") or not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d):
            for f in files:
                p = os.path.join(root, f)
                n += 1
                if not os.path.islink(p):
                    bad.append((p, "不是软链"))
                    continue
                real = os.path.realpath(p)
                if not real.startswith(os.path.realpath("scores") + os.sep):
                    bad.append((p, os.readlink(p)))
                if len(bad) > 8:
                    break
    ok(not bad, f"D. by_* 的 {n} 个链接全部指向 scores/ 里" + ("" if not bad else f"; 坏链示例: {bad[:5]}"))

    shutil.rmtree(tmp, ignore_errors=True)
    print("\n副作用自检 " + (f"失败 {len(fails)} 项" if fails else "通过"))
    for f in fails:
        print("  ✗ " + f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
