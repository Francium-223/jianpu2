# -*- coding: utf-8 -*-
"""静态找"**调用了但没定义**"的名字 —— 专抓"重构时删了函数、调用还留着"这类 bug。

为什么需要: 2026-09-24 实测 `propose_tags.py --from-tsv` 直接
`NameError: name 'apply_tsv' is not defined` —— 上一次重构把 `apply_tsv` 删了却留着调用。
而 `check_tools.sh` 只跑 `--help`, 根本走不到那一行, 所以没人发现(用户填完标签表格才会撞上)。

做法: 用 `ast` 收集模块里"定义过的名字"(def/class/赋值/import/参数/except/global/with…),
再收集所有"读取(Name Load)"的名字, 差集就是可疑的未定义调用。
**误报说明**: `from x import *` 会带来一批看不见的名字 -> 这类文件直接跳过并报出来。

用法:
    python3 tools/check_undefined.py            # 扫 tools/*.py 与 jianpu-db/*.py
    python3 tools/check_undefined.py 文件.py ...  # 指定文件
退出码: 0 = 没发现; 1 = 有可疑未定义名
"""
import ast
import builtins
import glob
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")


def defined_names(tree):
    d = set(dir(builtins))
    d |= {"__file__", "__name__", "__doc__", "self", "cls"}
    star = False
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            d.add(node.name)
        elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
            d.add(node.id)
        elif isinstance(node, ast.arg):
            d.add(node.arg)
        elif isinstance(node, ast.ExceptHandler) and node.name:
            d.add(node.name)
        elif isinstance(node, ast.Global):
            d.update(node.names)
        elif isinstance(node, ast.Import):
            for a in node.names:
                d.add((a.asname or a.name).split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            for a in node.names:
                if a.name == "*":
                    star = True
                else:
                    d.add(a.asname or a.name)
    return d, star


def check(path):
    try:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
    except SyntaxError as e:
        return [("语法错误", e.lineno, str(e))], False
    d, star = defined_names(tree)
    out = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id not in d:
            out.append(("未定义", node.lineno, node.id))
    return out, star


def main():
    args = sys.argv[1:]
    if args:
        files = args
    else:
        patterns = [os.path.join(HERE, "*.py"),                     # jianpu2/tools
                    os.path.join(DB, "*.py"),                       # jianpu-db
                    os.path.join(ROOT, "skills", "*", "*.py"),      # skill: jptok/lookup/eval_*
                    os.path.join(ROOT, "skills", "*", "selfcheck", "*.py"),
                    os.path.join(os.path.dirname(ROOT), "jianpu-web", "app", "*.py"),
                    os.path.join(os.path.dirname(ROOT), "jianpu-web", "tools", "*.py")]
        files = sorted({f for pat in patterns for f in glob.glob(pat)})
    bad = 0
    skipped = 0
    for f in files:
        if os.path.basename(f).startswith("_") and not args:
            continue                       # 下划线开头的是随手写的探针脚本, 不扫
        issues, star = check(f)
        name = os.path.relpath(f, os.path.dirname(ROOT))
        if star:
            print(f"  跳过(有 `import *`, 看不见的名字无法判断): {name}")
            skipped += 1
            continue
        if issues:
            bad += 1
            print(f"✗ {name}")
            for kind, line, what in issues[:8]:
                print(f"    第 {line} 行  {kind}: {what}")
        else:
            print(f"✓ {name}")
    print(f"\n扫了 {len(files)} 个文件: 有问题 {bad} 个, 跳过 {skipped} 个")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
