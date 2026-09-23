# -*- coding: utf-8 -*-
"""续跑夜间任务的后半段(4b 转写新爬的 -> 5 收尾 -> 6 对比验收)。
不碰 batch-out 已有结果(transcribe_source 会跳过已存在的), 所以可以安全重入。
"""
import glob, os, subprocess, sys, time
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

LOG = open("train-work/resume.log", "w", encoding="utf-8")
PY = sys.executable
ENV = dict(os.environ, JP_BATCH="8", JP_MAX_H="5000", JP_X_RECHECK="1")


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n")
    LOG.flush()


def sh(args, label):
    log(f"\n===== {label} =====")
    t0 = time.time()
    r = subprocess.run([PY] + args, env=ENV, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-8:]:
        log("  " + l)
    if r.returncode != 0 and r.stderr:
        log("  [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
    log(f"  ({time.time()-t0:.0f}s, exit={r.returncode})")


log("=== 续跑开始 ===")
log(f"当前 batch-out: {len(glob.glob('batch-out/*.txt'))} 个")
sh(["tools/transcribe_source.py", "images-prep/jianpucn-pop"], "4b) 继续转写新爬的")
sh(["tools/finalize.py"], "5) 收尾流水线")
log("\n===== 6) 对比与验收 =====")
sh(["tools/full_stats.py"], "6a) 最终统计")
sh(["tools/show_spring.py"], "6b) spring 锚点")
sh(["tools/verify_deliverable.py"], "6c) 交付物总验收")
log("\n=== 续跑完成 ===")
LOG.close()
