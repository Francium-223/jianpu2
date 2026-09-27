# -*- coding: utf-8 -*-
"""严格复验: 每个被加了 `--help` 守卫的工具, 跑 `--help` **必须打出 `[guard]` 标记**。

为什么不能只看"有没有输出": 第一版我只看"有输出就算过", 而 `finalize.py` 的守卫被插到了工作之后
—— 它照样有输出(那是**它真跑起来**的日志), 于是被我误判成通过。必须认标记。
"""
import ast
import io
import os
import subprocess
import sys

from guard import guard_help        # 本文件也被复验名单覆盖, 所以自己也要守卫
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

def _dotted(node):
    """把 `sys.path.insert` 这种**多级属性**还原成完整点号名。

    第一版只取了一层(`getattr(base,'id')` / `getattr(base,'attr')`), 于是 `sys.path.insert`
    被读成 `path.insert`, 与白名单对不上 —— 结果把 474 个工具里"只有路径设置"的那些全判成失败。
    """
    parts = []
    while isinstance(node, getattr(__import__("ast"), "Attribute")):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, getattr(__import__("ast"), "Name")):
        parts.append(node.id)
    return ".".join(reversed(parts))


def _harmless(node, src_lines):
    """这条模块级语句算不算"可能碰数据"?

    `sys.path.insert` / `sys.stdout.reconfigure` / `os.chdir` / 取 `sys.executable` 这类
    **纯设置**不动数据, 放在守卫前面没关系。真正要拦的是读文件、写文件、跑子进程、联网、删目录。
    """
    import ast as _ast
    if isinstance(node, _ast.Expr) and isinstance(node.value, _ast.Call):
        name = _dotted(node.value.func)
        if name in ("sys.path.insert", "sys.stdout.reconfigure", "sys.stderr.reconfigure",
                    "os.chdir", "warnings.filterwarnings", "random.seed"):
            return True
        # `os.environ.setdefault(...)` / `os.environ.update(...)` 之类**纯设置**也是无害的
        # (`t_min.py` 第一句就是 `import os; os.chdir(...); os.environ.setdefault('TOKENIZERS_PARALLELISM','false')`)
        if name.startswith("os.environ."):
            return True
    if isinstance(node, _ast.Assign) and len(node.targets) == 1:
        v = node.value
        if isinstance(v, _ast.Constant):
            return True
        if isinstance(v, _ast.Attribute) and getattr(v.value, "id", "") == "sys":
            return True
    return False


names = [n for n in (sys.argv[1:] or sorted(
    n for n in os.listdir(HERE) if n.endswith(".py")
    and "guard_help(" in io.open(os.path.join(HERE, n), encoding="utf-8").read()
)) if n != "guard.py"]          # guard.py 本身是守卫的实现, 不需要守卫

bad = []
for n in names:
    p = os.path.join(HERE, n)
    if not os.path.isfile(p):
        bad.append((n, "文件不存在"))
        continue
    src = io.open(p, encoding="utf-8").read()
    # 守卫必须在"第一条有副作用的模块级语句"之前
    tree = ast.parse(src)
    # 守卫行要认"真的调用"(行首就是 guard_help(), 或 import 那行), 不能把**字符串里**的
    # `guard_help(` 也算上 —— 本文件与 add_help_guard.py 的 GUARD 常量/文档里都有这个字样。
    guard_ln = None
    for i, l in enumerate(src.splitlines(), 1):
        s = l.strip()
        if s.startswith("guard_help(") or s.startswith("from guard import guard_help"):
            guard_ln = i
            break
    first_work = None
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Expr, ast.Assign)):
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant):
                continue                      # docstring
            if _harmless(node, src.splitlines()):
                continue
            if isinstance(node, (ast.Expr, ast.Assign)):
                first_work = node.lineno
                break
            continue
        first_work = node.lineno
        break
    if first_work is not None and guard_ln is not None and guard_ln > first_work:
        bad.append((n, "守卫(第%d行)在第一条实际代码(第%d行)**之后**" % (guard_ln, first_work)))
        continue
    try:
        r = subprocess.run([sys.executable, p, "--help"], cwd=ROOT,
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=20)
    except subprocess.TimeoutExpired:
        bad.append((n, "**超时(守卫没生效, 工具真跑起来了)**"))
        continue
    if "[guard]" not in (r.stdout or ""):
        bad.append((n, "没打出 [guard] 标记 (exit=%s, 头 60 字: %r)" % (r.returncode, (r.stdout or "")[:60])))
        continue
    print("  ✓ %s" % n)

print("\n严格复验: 通过 %d / 检查 %d" % (len(names) - len(bad), len(names)))
for n, why in bad:
    print("  ✗ %-30s %s" % (n, why))
sys.exit(1 if bad else 0)
