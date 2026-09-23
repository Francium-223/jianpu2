# -*- coding: utf-8 -*-
"""批量爬 jianpujia 的歌手/题材分类页(排版图, 质量远好于 jianpucn 的扫描图)。
分类 ID 来自首页普查(见 probe_jianpujia2.py 输出)。
日志: train-work/crawl_jianpujia.log
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

CATS = [
    ("583", "周杰伦"), ("499", "林俊杰"), ("315", "陈奕迅"), ("351", "薛之谦"),
    ("1134", "赵雷"), ("1192", "五月天"), ("362", "毛不易"), ("693", "许嵩"),
    ("478", "李荣浩"), ("1252", "邓丽君"), ("1380", "许巍"), ("3246", "Beyond"),
    ("21436", "影视"), ("3462", "儿歌"), ("22807", "民歌"), ("388", "主题曲"),
    ("20961", "游戏"), ("21159", "世界名曲"), ("6223", "草原"),
]

LOG = io.open("train-work/crawl_jianpujia.log", "w", encoding="utf-8")


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n")
    LOG.flush()


log(f"=== jianpujia 批量爬取 {len(CATS)} 个分类 ===")
for i, (cid, name) in enumerate(CATS, 1):
    log(f"\n[{i}/{len(CATS)}] {name} (list/{cid})")
    t0 = time.time()
    r = subprocess.run([PY, "tools/crawl_jianpujia.py", cid, name, "250"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-3:]:
        log("   " + l)
    if r.returncode != 0 and r.stderr:
        log("   [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
    log(f"   ({time.time()-t0:.0f}s)")
log("\n=== 完成 ===")
LOG.close()
