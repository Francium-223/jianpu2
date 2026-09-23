# -*- coding: utf-8 -*-
"""A) 用 qupu123 批量重爬大牌歌手(实测图片 2480x3507, 78% 宽>=1500px, 远好于 jianpucn)。

日志: train-work/crawl_qupu123.log
"""
import io
import os
import subprocess
import sys
import time

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PY = sys.executable

# (关键词, 目录短名, 目标数)
ARTISTS = [
    ("周杰伦", "zhoujielun", 120), ("邓丽君", "denglijun", 120),
    ("张学友", "zhangxueyou", 120), ("刘德华", "liudehua", 120),
    ("林俊杰", "linjunjie", 120), ("陈奕迅", "chenyixun", 120),
    ("五月天", "wuyuetian", 120), ("孙燕姿", "sunyanzi", 100),
    ("王菲", "wangfei", 100), ("周华健", "zhouhuajian", 100),
    ("Beyond", "beyond", 100), ("邓紫棋", "dengziqi", 100),
    ("薛之谦", "xuezhiqian", 100), ("李健", "lijian", 80),
    ("朴树", "pushu", 80), ("许巍", "xuwei", 80),
    ("汪峰", "wangfeng", 80), ("毛不易", "maobuyi", 80),
    ("凤凰传奇", "fenghuangchuanqi", 80), ("韩红", "hanhong", 80),
]

LOG = io.open("train-work/crawl_qupu123.log", "w", encoding="utf-8")


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n")
    LOG.flush()


log(f"=== qupu123 批量爬取 {len(ARTISTS)} 位歌手 ===")
for i, (kw, slug, n) in enumerate(ARTISTS, 1):
    log(f"\n[{i}/{len(ARTISTS)}] {kw} (目标 {n})")
    t0 = time.time()
    r = subprocess.run([PY, "tools/crawl_qupu123.py", kw, str(n), slug],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-2:]:
        log("   " + l)
    if r.returncode != 0 and r.stderr:
        log("   [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
    log(f"   ({time.time()-t0:.0f}s)")
log("\n=== 完成 ===")
LOG.close()
