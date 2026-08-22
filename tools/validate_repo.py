# -*- coding: utf-8 -*-
"""用 jianpu-db 的 score.py 批量验证草稿的仓库兼容性 (parse 不报错即兼容)。

用法: python tools/validate_repo.py [输出目录...]
默认验证全部 scores-* 目录。沙箱: tools/jpdbtest/ (含 score.py 与 tag 文件副本)。
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SANDBOX = os.path.join(ROOT, "jpdbtest")

DIRS = sys.argv[1:] or [
    "scores-draft", "scores-draft2", "scores-draft3", "scores-draft4",
    "scores-draft5", "scores-draft-pucn", "scores-draft-pujia",
    "scores-7b", "scores-7b-2", "scores-7b-3", "scores-7b-4", "scores-7b-5",
    "scores-7b-pucn", "scores-7b-pujia",
]

WORK = os.path.join(ROOT, "..")


def reset_sandbox():
    for d in ("scores", "by_title", "by_tag", "by_alias", "by_mbid"):
        p = os.path.join(SANDBOX, d)
        if os.path.isdir(p):
            shutil.rmtree(p)
        os.makedirs(p)
    # 只清派生文件, 保留 tag_implications.json / tag_equality.json / score.py
    for f in os.listdir(SANDBOX):
        if f.endswith("_buf.txt") or f.endswith("_buf.json") or f.endswith("_expand.txt"):
            os.unlink(os.path.join(SANDBOX, f))


def main():
    reset_sandbox()
    sys.path.insert(0, SANDBOX)
    os.chdir(SANDBOX)
    import score as score_mod  # noqa: E402

    total = ok = 0
    results = []
    for d in DIRS:
        src = os.path.join(WORK, d)
        if not os.path.isdir(src):
            continue
        files = [f for f in sorted(os.listdir(src)) if f.endswith(".txt")]
        d_ok = 0
        for name in files:
            dst = os.path.join(SANDBOX, "scores", name)
            shutil.copyfile(os.path.join(src, name), dst)
            total += 1
            try:
                score_mod.Score(f"scores/{name}").parse()
                d_ok += 1
            except Exception as e:
                results.append((False, d, name, f"{type(e).__name__}: {e}"))
        ok += d_ok
        print(f"{d}: {d_ok}/{len(files)} 通过")
    print(f"\n总计: {ok}/{total} 通过, {total - ok} 失败")
    for passed, d, name, err in results:
        print(f"  [FAIL] {d}/{name}: {err}")
    report = os.path.join(WORK, "repo_validation_report.txt")
    with open(report, "w", encoding="utf-8") as f:
        f.write(f"通过 {ok}/{total}\n\n")
        for passed, d, name, err in results:
            f.write(f"FAIL {d}/{name} {err}\n")
    print(f"报告: {report}")


if __name__ == "__main__":
    main()
