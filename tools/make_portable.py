# -*- coding: utf-8 -*-
"""把硬编码的 os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) 换成从文件位置推断根路径 —— 可迁移化。

替换很保守, 只动这一行:
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
  ->
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

脚本都在 <root>/tools/ 下, 所以 dirname(dirname(abspath(__file__))) 就是 <root>。
前面那行 `sys.path.insert(0, "tools")` 是相对路径, chdir 之后正好解析成 <root>/tools, 不受影响。
用法: py tools/make_portable.py [--dry]
"""
import glob, io, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

DRY = "--dry" in sys.argv
OLD = 'os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))'
NEW = 'os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))'

def imports_os(s):
    # 匹配各种写法: "import os" / "import os, sys" / "import glob, os, re" /
    # 以及单行式 "import sys; ...; import os; os.chdir(...)"
    return bool(re.search(r"\bimport\b[^\n]*\bos\b", s))

changed = []
for p in sorted(glob.glob("tools/*.py")):
    s = io.open(p, encoding="utf-8").read()
    if OLD not in s:
        continue
    if not imports_os(s):
        print(f"  跳过(确实没导入 os): {p}")
        continue
    n = s.count(OLD)
    if not DRY:
        io.open(p, "w", encoding="utf-8").write(s.replace(OLD, NEW))
    changed.append((p, n))

print(f"{'[dry] ' if DRY else ''}改了 {len(changed)} 个脚本:")
for p, n in changed:
    print(f"   {p}  ({n} 处)")
