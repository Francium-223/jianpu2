# -*- coding: utf-8 -*-
"""看一眼 raw batch-out 里 `(` / `~` 出现在什么上下文(判断是哪种标记)。"""
import glob
import os
import sys
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

for mark in ("(", "~"):
    print(f"===== 标记 {mark!r}")
    n = 0
    for f in glob.glob("batch-out/*.txt"):
        if os.path.basename(f) == "progress.txt":
            continue
        toks = open(f, encoding="utf-8", errors="replace").read().split()
        idx = [k for k, x in enumerate(toks) if x == mark]
        if not idx:
            continue
        print(f"  {os.path.basename(f)[:44]}")
        print("     ", " ".join(toks[max(0, idx[0] - 7):idx[0] + 9]))
        n += 1
        if n >= 3:
            break
