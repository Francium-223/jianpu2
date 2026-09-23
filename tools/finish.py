# -*- coding: utf-8 -*-
"""一条命令完成全部收尾 —— 万一自动驾驶(autopilot)随会话结束被中断, 跑这个即可。

  py -3.13 tools/finish.py

依次: 收尾流水线(7步) -> GT 评测 -> 交付物总验收 -> 最终统计
日志: train-work/finish.log
"""
import os, subprocess, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
LOG = open("train-work/finish.log", "w", encoding="utf-8")

def log(m):
    print(m, flush=True)
    LOG.write(m + "\n"); LOG.flush()

def sh(args, label):
    log(f"\n===== {label} =====")
    t0 = time.time()
    r = subprocess.run([sys.executable] + args, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-14:]:
        log("  " + l)
    if r.returncode != 0 and r.stderr:
        log("  [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
    log(f"  ({time.time()-t0:.0f}s, exit={r.returncode})")

log("=== 手动收尾开始 ===")
sh(["tools/finalize.py"], "1) 收尾流水线(纯度过滤→版本择优→重建 scores→来源映射→下游)")
sh(["tools/eval_gt_images.py"], "2) GT 评测")
sh(["tools/full_stats.py"], "3) 最终统计")
sh(["tools/verify_deliverable.py"], "4) 交付物总验收")
log("\n=== 完成。交付物: jianpu-db-out/scores/ 与 train-work/jpdbtest/out.jsonl ===")
LOG.close()
