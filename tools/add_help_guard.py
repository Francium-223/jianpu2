# -*- coding: utf-8 -*-
"""给"没有 argparse / 没有 --help 守卫"的工具**自动插入**守卫(见 tools/guard.py)。

为什么要自动插而不是手改: 这类工具有 494 个, 手改迟早漏; 而插入位置必须精确 ——
**只能在 import 块之后、任何有副作用的模块级代码之前**, 插错位置等于没插(甚至更糟)。

做法: 用 `ast` 解析, 取模块级 docstring + 所有 Import/ImportFrom 的最大结束行, 插在其后。
插完逐个 `ast.parse` 复验; 默认是 **dry-run**, 加 `--apply` 才写。

用法:
    py -3.13 tools/add_help_guard.py --corpus --dry     # 只看"会写语料"的那 20 个
    py -3.13 tools/add_help_guard.py --corpus --apply
    py -3.13 tools/add_help_guard.py --list a.py,b.py --apply
"""
import argparse
import ast
import io
import os
import sys

from guard import guard_help        # 本文件自己也要守卫(它会被冒烟自检 --help 调)
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

GUARD = ("from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)\n"
         "guard_help(__doc__)\n")


def insertion_line(src):
    """返回应插入的行号(0-based, 插在该行之前); 已有守卫或解析失败返回 None。

    ⚠ 2026-09-28 修正: 原来取的是"**所有**模块级 import 的最大结束行"。对
    `finalize.py` 这种"先干活、后面还有 import"的文件, 守卫就被插到**工作之后**了 ——
    实测 `finalize.py --help` 照样真跑起来(扫纯度→择优→重建), 而且因为不认 --help,
    它把两遍收尾流水线都跑完了。正确做法是取**开头连续的那段导入块**(docstring 之后,
    遇到第一条非 import 语句就停)。
    `from guard import guard_help` 不需要 HERE 在 sys.path 上: 以脚本方式运行时
    `sys.path[0]` 就是 tools/ 本身。
    """
    if "guard_help(" in src:
        return None
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return None
    last = 0
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            last = max(last, getattr(node, "end_lineno", node.lineno))
        elif isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant) \
                and isinstance(node.value.value, str) and node.lineno <= 3:
            last = max(last, getattr(node, "end_lineno", node.lineno))
        else:
            break                      # 开头连续段结束 -> 再往后就是有副作用的代码了
    return last


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", action="store_true", help="只处理\"会写语料\"的那批")
    ap.add_argument("--list", default="", help="逗号分隔的文件名")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--move", action="store_true",
                    help="已有守卫但位置不对时, 先摘掉再插到正确位置(第一条实际代码之前)")
    a = ap.parse_args()

    if a.list:
        names = [x.strip() for x in a.list.split(",") if x.strip()]
    else:
        sys.path.insert(0, HERE)
        import re
        names = []
        for n in sorted(os.listdir(HERE)):
            if not n.endswith(".py") or n.startswith("_") or n in ("guard.py", "add_help_guard.py"):
                continue
            src = io.open(os.path.join(HERE, n), encoding="utf-8").read()
            if "argparse" in src or "'--help'" in src or '"--help"' in src:
                continue
            if a.corpus:
                if not re.search(r"add_to_score_file|add_usertag|add_field|SCORES|scores/", src):
                    continue
                if not re.search(r"""open\([^)]*['"]w|unlink|\.remove\(|\.rename\(|shutil\.move""", src):
                    continue
            names.append(n)

    done, skip = [], []
    for n in names:
        p = os.path.join(HERE, n)
        if not os.path.isfile(p):
            skip.append((n, "文件不存在"))
            continue
        src = io.open(p, encoding="utf-8").read()
        if "guard_help(" in src:
            if not a.move:
                skip.append((n, "已有守卫(要挪位置加 --move)"))
                continue
            # 摘掉旧守卫(整行匹配, 免得误删别的代码)
            kept = [l for l in src.splitlines(keepends=True)
                    if "guard_help(__doc__)" not in l and "from guard import guard_help" not in l]
            src = "".join(kept)
        ln = insertion_line(src)
        if ln is None:
            skip.append((n, "解析不了"))
            continue
        lines = src.splitlines(keepends=True)
        new = "".join(lines[:ln]) + GUARD + "".join(lines[ln:])
        try:
            ast.parse(new)
        except SyntaxError as e:
            skip.append((n, "插完语法坏了: %s" % e))
            continue
        if a.apply:
            io.open(p, "w", encoding="utf-8", newline="").write(new)
        done.append((n, ln + 1))

    print("%s %d 个; 跳过 %d 个" % ("已插" if a.apply else "将插(dry-run)", len(done), len(skip)))
    for n, ln in done:
        print("   %-34s 插在第 %d 行之后" % (n, ln))
    for n, why in skip:
        print("   -- %-31s %s" % (n, why))
    if not a.apply:
        print("\n(加 --apply 才真的写)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
