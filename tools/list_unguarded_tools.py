# -*- coding: utf-8 -*-
"""列出**没有 --help 保护**的工具 —— 也就是"用 --help 探测会让它们真跑起来"的那批。

为什么要单独列: 项目自带的 `check_tools.sh`（以及我写的 Windows 版）都用 `--help` 探测每个工具能否
import。对没有 argparse、也没有 `--help` 守卫的工具, 这个探测会**把它们当正常参数启动**。
2026-09-28 实测后果: `autopilot.py` 空等一小时、`add_copyright.py` 改写了 266 个草稿、
`bench_batch.py` 开始加载模型重转写(与流水线抢 GPU)。这份名单用来决定"哪些工具该补守卫"。
"""
import glob
import os
import re
import sys
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

TOOLS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools")
DQ = chr(34)

rows = []
for p in sorted(glob.glob(os.path.join(TOOLS, "*.py"))):
    n = os.path.basename(p)
    if n.startswith("_"):
        continue
    try:
        src = open(p, encoding="utf-8").read()
    except Exception:
        continue
    if "argparse" in src or "'--help'" in src or (DQ + "--help" + DQ) in src:
        continue
    # 粗判它会不会"干活": 有没有读写文件/起子进程/联网
    risky = any(k in src for k in ("open(", "io.open", "subprocess", "urlopen", "shutil",
                                   "os.rename", "os.remove", "Image", "torch"))
    # 更狠的一档: **会写语料**(唯一实现那几个函数 / 直接改 scores)
    corpus = bool(re.search(r"add_to_score_file|add_usertag|add_field|SCORES|scores/", src)) and \
        bool(re.search(r"""open\([^)]*['"]w|unlink|\.remove\(|\.rename\(|shutil\.move""", src))
    rows.append((n, "写语料" if corpus else ("有副作用风险" if risky else "看着只读")))

want = sys.argv[1] if len(sys.argv) > 1 else ""
if want == "--corpus":
    rows = [r for r in rows if r[1] == "写语料"]
elif want == "--risky":
    rows = [r for r in rows if r[1] != "看着只读"]

print("没有 --help 保护的工具: %d 个%s" % (len(rows), ("（筛选: %s）" % want) if want else ""))
for n, tag in rows:
    print("   %-34s %s" % (n, tag))
sys.exit(0)
