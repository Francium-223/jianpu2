# -*- coding: utf-8 -*-
"""按"源质量优先"转写新爬的谱, 然后收尾。

优先级依据(实测):
  * jianpujia = 排版渲染图 -> 清晰 -> 先转 (周杰伦那批实测到 2377x3362)
  * qupu123   = 中位 973px    -> 次之
  * jianpucn  = 中位 730px 扫描件 -> 兜底覆盖, 最后转

磁盘保护: 每转完一个源, 删除该源的"已转写"标注图以外的临时文件; 并在剩余空间 <1.2GB 时停手。
日志: train-work/transcribe_priority.log
"""
import glob
import io
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PY = sys.executable
ENV = dict(os.environ, JP_BATCH="8", JP_MAX_H="5000", JP_X_RECHECK="1", JP_NOPNG="1")

LOG = io.open("train-work/transcribe_priority.log", "w", encoding="utf-8")


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n")
    LOG.flush()


def free_gb():
    return shutil.disk_usage(".").free / (1024 ** 3)


def sources_by_quality():
    """按源质量排序(目录名首段), 高质量在前。"""
    prio = {"jianpujia": 0, "qupu123": 1, "qinyipu": 1, "jianpucn": 2}
    out = []
    for d in sorted(glob.glob("images-prep/*")):
        if not os.path.isdir(d):
            continue
        base = os.path.basename(d)
        key = base.split("-")[0]
        if base == "jianpucn-pop":
            key = "jianpucn"
        n = len([x for x in glob.glob(d + "/*") if os.path.isdir(x)])
        if n:
            # 同质量档内 **小批次优先**(+n 升序): 新爬的高清批次通常几十到几百首,
            # 先做完能快速看到效果; 写成 -n 会变成"先啃最大的历史批"(实测踩过:
            # 它一头扎进 3412 首的 qupu123-crawl, 把新高清批排在几小时之后)。
            out.append((prio.get(key, 3), n, d))
    return [(d, n) for _p, _n2, d, n in
            [(p, n, d, n) for p, n, d in sorted(out)]]


log("=== 按源质量优先转写 ===")
for d, n in sources_by_quality():
    fg = free_gb()
    if fg < 1.2:
        log(f"\n[磁盘 {fg:.1f} GB < 1.2 GB, 停止转写]")
        break
    # 已转过的跳过(该源下已有 batch-out txt 的比例)
    done = 0
    for sub in glob.glob(d + "/*"):
        if os.path.isdir(sub):
            import batch_transcribe as BT
            if os.path.exists(os.path.join("batch-out", BT.safe_name(os.path.basename(sub)) + ".txt")):
                done += 1
    if done >= n:
        log(f"\n跳过 {d} ({n} 个已全部转过)")
        continue
    log(f"\n--- {d}  ({n} 个, 已转 {done}) 磁盘 {fg:.1f} GB ---")
    t0 = time.time()
    r = subprocess.run([PY, "tools/transcribe_source.py", d], env=ENV,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-4:]:
        log("   " + l)
    if r.returncode != 0 and r.stderr:
        log("   [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
    log(f"   ({time.time()-t0:.0f}s, 磁盘剩 {free_gb():.1f} GB)")

log("\n=== 收尾 ===")
for args, label in [(["tools/finalize.py"], "收尾流水线"),
                    (["tools/full_stats.py"], "统计"),
                    (["tools/verify_deliverable.py"], "总验收")]:
    log(f"\n--- {label} ---")
    r = subprocess.run([PY] + args, env=ENV, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-10:]:
        log("   " + l)
    if r.returncode != 0 and r.stderr:
        log("   [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
log("\n=== 完成 ===")
LOG.close()
