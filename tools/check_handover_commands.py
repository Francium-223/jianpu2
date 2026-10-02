# -*- coding: utf-8 -*-
"""文档里的 `tools/...` 引用体检（只读，默认查交接文档，可传别的文件/目录）。

两个判据:
  ① **存在性**: 每个 `tools/xxx` 至少要在三个仓库之一里真的存在（否则照文档敲就是 No such file）；
  ② **跨仓库要写明仓库**（判据是**当前这一行**里有仓库名 —— 邻近行的说明不算）: 如果它只存在于**别的**仓库（比如 `build_web_data.py` 只在
     `jianpu-db.github.io`），那么同一行/邻近文字里必须点名那个仓库 —— 否则读者会在
     `jianpu2` 里敲、然后报"文件不存在"。

用法: py -3.13 tools/check_handover_commands.py                 # 默认查 醒来交接_E阶段.md
      py -3.13 tools/check_handover_commands.py <文件或目录>      # 查指定的 md（目录则递归）
"""
import io
import os
import re
import sys

def _rel(p, base):
    """相对路径（只为打印）—— Windows 上跨盘 relpath 会抛 ValueError，退化成绝对路径。"""
    try:
        return os.path.relpath(p, base)
    except ValueError:
        return p
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)
REPOS = ["jianpu2", "jianpu-db", "jianpu-db.github.io"]


def repo_of(path):
    """文件属于哪个仓库（按路径判断）—— 文档引用**自己仓库**的 tools/ 时不需要点名仓库。

    ⚠ 必须**取最长的仓库名**再比: `jianpu-db` 是 `jianpu-db.github.io` 的**前缀**，
    按 REPOS 原顺序比会把站点仓库的文档误判成 jianpu-db 的（2026-10-03 实测踩过）。
    """
    p = os.path.normcase(os.path.abspath(path))
    for r in sorted(REPOS, key=len, reverse=True):
        if os.path.normcase(os.path.join(WS, r)) in p:
            return r
    return ""


# 历史报告：里面的 `tools/xxx` 写的是**当时**的状态，不该按今天的仓库内容判死刑
# 明知不存在的引用: `tools/pip-tmp/` —— README 自己就写着"是本机沙箱遗留的锁死目录, 可手动删除"，
# 也就是那行**在说明它不存在**，不是让人去跑它。列在这里而不是静默忽略。
BENIGN = {"pip-tmp"}
HISTORICAL = re.compile(r"(醒来汇报_v\d+|_关机交接|^STATE\.md$|MIGRATION|训练报告|交付总结|执行报告|_v\d+\.md$)", re.I)

_arg = next((a for a in sys.argv[1:] if not a.startswith("-")), "")
if not _arg:
    DOCS = [os.path.join(ROOT, "醒来交接_E阶段.md")]
elif os.path.isdir(_arg):
    DOCS = []
    for dp, _dn, fns in os.walk(_arg):
        if re.search(r"(node_modules|\\\.git|\\dist|__pycache__|by_|\\scores|\\misc\\|images|_analysis|train-work)", dp):
            continue
        DOCS += [os.path.join(dp, f) for f in fns if f.endswith(".md")]
else:
    DOCS = [_arg]

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


missing, cross, ok = [], [], 0
for doc in DOCS:
    txt = io.open(doc, encoding="utf-8", errors="replace").read()
    lines = txt.splitlines()
    refs = {}
    for i, line in enumerate(lines, 1):
        for m in re.finditer(r"tools[\\/]([A-Za-z0-9_\.\-]+)", line):
            refs.setdefault(m.group(1), []).append((i, line))
    if not refs:
        continue
    rel = _rel(doc, WS)
    own = repo_of(doc)
    hist = bool(HISTORICAL.search(os.path.basename(doc)))
    print("── %s（引用 %d 个%s%s）" % (rel, len(refs), "，本仓库 " + own if own else "", "，**历史报告**（跳过跨仓库判定）" if hist else ""))
    for name in sorted(refs):
        if not name.strip(".") or name.endswith(".zip") or name in BENIGN:   # 省略号 / Kaggle 输入包 / 明知不存在的
            continue
        hits = where(name)
        if not hits:
            if not hist:
                missing.append((rel, name, refs[name][0]))
            continue
        if hist or (own and hits == [own]):
            ok += 1
        elif hits == ["jianpu2"]:
            ok += 1
        else:
            # 只存在于别的仓库 -> 看提到它的那些行有没有点名仓库/给出路径
            bad = [(ln, s) for ln, s in refs[name]
                   if not any(h in s for h in SITE_HINTS) and "jianpu-db" not in s and "jianpu2" not in s]
            if bad:
                cross.append((rel, name, hits, bad[0]))
            else:
                ok += 1

print()
print("扫了 %d 份文档；引用 %d 个在 jianpu2 或已写明仓库 ✓" % (len(DOCS), ok))
print()
if missing:
    print("✗ 三个仓库里都找不到的引用（照文档敲会 No such file）:")
    for rel, name, (ln, s) in missing:
        print("    %-40s %s 第 %d 行: %s" % (name, rel, ln, s.strip()[:60]))
else:
    print("✓ 没有「找不到」的引用")
print()
if cross:
    print("⚠ 只存在于别的仓库、但提到它的地方**没写明仓库**:")
    for rel, name, hits, (ln, s) in cross:
        print("    %-28s 在 %s；%s 第 %d 行: %s" % (name, "/".join(hits), rel, ln, s.strip()[:50]))
else:
    print("✓ 跨仓库引用都写明了仓库")