# -*- coding: utf-8 -*-
"""列出 `batch-out/` 里"0 音符"的残留件（只读，不动文件）。

为什么: `tools/verify_deliverable.py` 有一条门槛「0 音符已清空」，本轮实测还剩 10 个。
按仓库既有口径，这类件该在 `batch-out-empty/`（那个目录已经有 481 件），
所以先**列出来看**（名字/大小/mtime），别直接动手 —— 流水线正在转写时搬文件会跟它抢。
"""
import glob
import io
import os
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def digits(tokens):
    n = 0
    for x in tokens:
        y = x.lstrip("qsdh,").rstrip("'.")
        if y and y[-1] in "1234567":
            n += 1
    return n


rows = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b in ("progress.txt", "skipped.txt"):
        continue
    t = io.open(f, encoding="utf-8", errors="replace").read().split()
    if digits(t) == 0:
        st = os.stat(f)
        rows.append((b, len(t), st.st_size, st.st_mtime))
rows.sort(key=lambda r: -r[3])
print("batch-out 里 0 音符的件: %d 个（按 mtime 新→旧）" % len(rows))
import time
for b, n, sz, mt in rows:
    print("  %s  token=%d  %dB  %s" % (b[:58].ljust(58), n, sz, time.strftime("%m-%d %H:%M", time.localtime(mt))))
print()
print("对照: batch-out-empty/ 现有 %d 件（既有的隔离区）" % len(glob.glob("batch-out-empty/*")))
newest = max((r[3] for r in rows), default=0)
print("最新的一个 mtime: " + time.strftime("%Y-%m-%d %H:%M", time.localtime(newest)))
