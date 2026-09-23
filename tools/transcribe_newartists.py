# -*- coding: utf-8 -*-
"""转写新爬的大牌歌手(邓丽君优先), 转完自动用待查旋律再搜一遍。
日志: train-work/newartists.log
"""
import glob, os, subprocess, sys, time
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

LOG = open("train-work/newartists.log", "w", encoding="utf-8")
PY = sys.executable
ENV = dict(os.environ, JP_BATCH="8", JP_MAX_H="5000", JP_X_RECHECK="1")

# 顺序即优先级: 邓丽君(用户在等) -> 周杰伦 -> 其余
SRC = [
    "images-prep/jianpucn-denglijun",
    "images-prep/jianpucn-zhoujielun",
]


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n"); LOG.flush()


def sh(args, label):
    log(f"\n===== {label} =====")
    t0 = time.time()
    r = subprocess.run([PY] + args, env=ENV, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-5:]:
        log("  " + l)
    if r.returncode != 0 and r.stderr:
        log("  [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
    log(f"  ({time.time()-t0:.0f}s)")


log("=== 转写新爬的大牌歌手 ===")
for s in SRC:
    if os.path.isdir(s):
        n = len([d for d in glob.glob(s + "/*") if os.path.isdir(d)])
        log(f"\n源 {s}: {n} 个目录")
        sh(["tools/transcribe_source.py", s], f"转写 {os.path.basename(s)}")

log("\n=== 待查旋律复查 ===")
for q in ["3563121253", "67111137766654511"]:
    log(f"\n--- 查询 {q} ---")
    r = subprocess.run([PY, "tools/melody_find.py", q, "--fuzzy", "1", "--top", "8"],
                       env=ENV, capture_output=True, text=True, encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines():
        log("  " + l)
log("\n=== 完成 ===")
LOG.close()
