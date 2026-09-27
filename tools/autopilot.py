# -*- coding: utf-8 -*-
"""自动驾驶: 等当前转写结束后, 依次完成
  1) 收尾流水线(纯度过滤 + 版本择优 + 重建 scores + 下游)
  2) GT 评测(用 train-work/gt/ 里"图+同名txt"的 4 组)
  3) 再爬一批歌手
  4) 转写新爬的
  5) 再收尾一次
全程后台, 不需要人盯。日志: train-work/autopilot.log
"""
import glob, os, subprocess, sys, time

# ⚠ 2026-09-28: **`--help` 保护**。本文件没有 argparse, 所以 `autopilot.py --help` 会**当成正常启动**
#   直接跑起来 —— 实测被工具的冒烟自检(`check_tools.ps1` / `check_tools.sh` 都会这样调每个工具)
#   误启动, 而且它第一步是 `wait_for_idle()`: 等"没有 python.exe 在跑", 而转写流水线一直在跑,
#   于是**空等一小时**、把冒烟自检整条卡死(别的工具都没被验到)。同一个坑 `mbid_lookup.py`
#   在 09-25 也踩过(那次是白打 MusicBrainz API), 这里补上同样的守卫。
if any(a in ("-h", "--help") for a in sys.argv[1:]):
    print(__doc__.strip())
    raise SystemExit(0)

sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
LOG = open("train-work/autopilot.log", "w", encoding="utf-8")

def log(m):
    print(m, flush=True)
    LOG.write(m + "\n"); LOG.flush()

def sh(args, label, cwd=None, env=None):
    log(f"\n===== {label} =====")
    t0 = time.time()
    e = dict(os.environ); e.update(env or {})
    r = subprocess.run([sys.executable] + args, cwd=cwd, env=e,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-12:]:
        log("  " + l)
    if r.returncode != 0 and r.stderr:
        log("  [stderr] " + r.stderr.strip().splitlines()[-1])
    log(f"  ({time.time()-t0:.0f}s, exit={r.returncode})")
    return r

def nt():
    return len(glob.glob("batch-out/*.txt"))

def busy():
    """是否有"别的" python 在跑(排除自己, 否则永远为真)。"""
    r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq python.exe", "/FO", "CSV", "/NH"],
                       capture_output=True, text=True, errors="replace")
    me = str(os.getpid())
    for line in (r.stdout or "").splitlines():
        parts = [p.strip('"') for p in line.split('","')]
        if len(parts) >= 2 and parts[0].lower().startswith("python") and parts[1] != me:
            return True
    return False

log("=== 自动驾驶启动 ===")
last, stable = nt(), 0
log(f"当前 batch-out {last} 个")
while True:
    time.sleep(60)
    n = nt()
    if n == last and not busy():
        stable += 1
    else:
        stable = 0
    last = n
    if stable >= 5:
        log(f"转写已结束({n} 个, 静止 5 分钟)")
        break

# 1) 收尾
sh(["tools/finalize.py"], "1) 收尾流水线")

# 2) GT 评测
sh(["tools/eval_gt_images.py"], "2) GT 评测")

# 3+4) 再爬一批并转写
sh(["tools/crawl_pop.py", "400", "40"], "3) 再爬歌手")
sh(["tools/build_next_batch.py"], "3b) 建新名单")
sh(["tools/transcribe_source.py", "train-work/next_batch.txt"], "4) 转写新爬",
   env={"JP_BATCH": "8", "JP_MAX_H": "5000", "JP_X_RECHECK": "1"})

# 5) 再收尾
sh(["tools/finalize.py"], "5) 再收尾")

log("\n=== 自动驾驶完成 ===")
sh(["tools/full_stats.py"], "最终统计")
sh(["tools/verify_deliverable.py"], "交付物总验收")
LOG.close()
