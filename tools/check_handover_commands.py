# -*- coding: utf-8 -*-
"""交接文档里的 `tools/...` 引用体检（只读）。

两个判据:
  ① **存在性**: 每个 `tools/xxx` 至少要在三个仓库之一里真的存在（否则照文档敲就是 No such file）；
  ② **跨仓库要写明仓库**: 如果它只存在于**别的**仓库（比如 `build_web_data.py` 只在
     `jianpu-db.github.io`），那么同一行/邻近文字里必须点名那个仓库 —— 否则读者会在
     `jianpu2` 里敲、然后报"文件不存在"。

用法: py -3.13 tools/check_handover_commands.py
"""
import io
import os
import re
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)
DOC = os.path.join(ROOT, "醒来交接_E阶段.md")
REPOS = ["jianpu2", "jianpu-db", "jianpu-db.github.io"]

# 站点仓库在文里的常见写法（用来判断"有没有点名仓库"）
SITE_HINTS = ("jianpu-db.github.io", "站点仓库", "在 `jianpu-db.github.io`", "site")


def where(name):
    """这个 tools/<name> 在哪些仓库里存在。"""
    hits = []
    for r in REPOS:
        for sub in ("tools", os.path.join("tools", ""), ""):
            p = os.path.join(WS, r, sub, name) if sub else os.path.join(WS, r, name)
            if os.path.isfile(p):
                hits.append(r)
                break
    return hits


txt = io.open(DOC, encoding="utf-8").read()
lines = txt.splitlines()
refs = {}
for i, line in enumerate(lines, 1):
    for m in re.finditer(r"tools[\\/]([A-Za-z0-9_\.\-]+)", line):
        refs.setdefault(m.group(1), []).append((i, line))

missing, cross, ok = [], [], 0
for name in sorted(refs):
    hits = where(name)
    if not hits:
        missing.append((name, refs[name][0]))
    elif hits == ["jianpu2"]:
        ok += 1
    else:
        # 只存在于别的仓库 -> 看提到它的那些行有没有点名仓库/给出路径
        bad = [(ln, s) for ln, s in refs[name]
               if not any(h in s for h in SITE_HINTS) and "jianpu-db" not in s and "jianpu2" not in s]
        if bad:
            cross.append((name, hits, bad[0]))
        else:
            ok += 1

print("交接里出现的 tools/ 引用: %d 个（%d 个在 jianpu2 或已写明仓库 ✓）" % (len(refs), ok))
print()
if missing:
    print("✗ 三个仓库里都找不到的引用（照文档敲会 No such file）:")
    for name, (ln, s) in missing:
        print("    %-38s 第 %d 行: %s" % (name, ln, s.strip()[:70]))
else:
    print("✓ 没有「找不到」的引用")
print()
if cross:
    print("⚠ 只存在于别的仓库、但提到它的地方**没写明仓库**:")
    for name, hits, (ln, s) in cross:
        print("    %-30s 在 %s；第 %d 行: %s" % (name, "/".join(hits), ln, s.strip()[:60]))
else:
    print("✓ 跨仓库引用都写明了仓库")
