# -*- coding: utf-8 -*-
"""夜间流程: 给语料补上"连音线/圆滑线"标记 + 扩充流行歌, 跑完自动收尾对比。

为什么要重跑: 连音线/圆滑线转写(同音->~, 不同音->( ))是刚做的, 现有 2022 个结果是
旧代码转的, 里面没有标记。

安全措施:
  * 重跑前把 batch-out 的 txt 备份到 train-work/corpus-bak/ (已另存一份)
  * **只重转当前语料里的谱**(不碰已隔离的非纯/重复谱, 省时间)
  * 跑完对比: 语料规模 / spring 锚点 / GT 评测, 打印出来供人工判断

日志: train-work/overnight.log
"""
import glob, os, shutil, subprocess, sys, time
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

LOG = open("train-work/overnight.log", "w", encoding="utf-8")
PY = sys.executable
ENV = dict(os.environ, JP_BATCH="8", JP_MAX_H="5000", JP_X_RECHECK="1")


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n")
    LOG.flush()


def sh(args, label, timeout=None):
    log(f"\n===== {label} =====")
    t0 = time.time()
    try:
        r = subprocess.run([PY] + args, env=ENV, timeout=timeout,
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        for l in (r.stdout or "").strip().splitlines()[-10:]:
            log("  " + l)
        if r.returncode != 0 and r.stderr:
            log("  [stderr] " + (r.stderr.strip().splitlines() or [""])[-1])
        log(f"  ({time.time()-t0:.0f}s, exit={r.returncode})")
        return r.returncode
    except subprocess.TimeoutExpired:
        log(f"  [超时 {timeout}s]")
        return -1


def corpus_dirs():
    """当前语料里的谱(有 batch-out 结果的), 返回目录名列表。"""
    have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
    have -= {"progress", "skipped"}
    out = []
    for d in sorted(x for x in glob.glob("images-prep/*/*") if os.path.isdir(x)):
        name = os.path.basename(d.rstrip("/\\"))
        if BT.safe_name(name) in have:
            out.append(name)
    return out


log("=== 夜间流程启动 ===")
log(f"当前语料: {len(glob.glob('batch-out/*.txt'))} 个 txt")

# 0) 备份(再保一次, 以防万一)
os.makedirs("train-work/corpus-bak", exist_ok=True)
n_bak = 0
for f in glob.glob("batch-out/*.txt"):
    if os.path.basename(f) in ("progress.txt", "skipped.txt"):
        continue
    dst = os.path.join("train-work/corpus-bak", os.path.basename(f))
    if not os.path.exists(dst):
        shutil.copy(f, dst)
        n_bak += 1
log(f"0) 备份新增 {n_bak} 个 txt 到 train-work/corpus-bak/")

# 1) 先记下要重转的名单(在删除之前算)
todo = corpus_dirs()
log(f"1) 待重转(当前语料): {len(todo)} 个")

# 2) 再爬一批流行歌手（JP_SKIP_CRAWL=1 时跳过, 便于续跑）
if os.environ.get("JP_SKIP_CRAWL", "") != "1":
    sh(["tools/crawl_pop.py", "400", "40"], "2) 爬新歌手", timeout=3600)
else:
    log("2) 跳过爬虫(JP_SKIP_CRAWL=1)")

# 3) 清空 batch-out(腾出磁盘: 标注图可重生成), 保留 txt 备份
n_del = 0
for f in glob.glob("batch-out/*.txt") + glob.glob("batch-out/*.png"):
    if os.path.basename(f) in ("progress.txt", "skipped.txt"):
        continue
    os.remove(f)
    n_del += 1
log(f"\n3) 清空 batch-out {n_del} 个文件(备份在 train-work/corpus-bak/)")

# 4) 重转名单里的谱 + 新爬的(jianpucn-pop 整源)
with open("train-work/overnight_list.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(todo))
sh(["tools/transcribe_source.py", "train-work/overnight_list.txt"], "4a) 重转当前语料", timeout=None)
sh(["tools/transcribe_source.py", "images-prep/jianpucn-pop"], "4b) 转写新爬的", timeout=None)

# 5) 收尾
sh(["tools/finalize.py"], "5) 收尾流水线", timeout=None)

# 6) 对比 + 验收
log("\n===== 6) 对比与验收 =====")
sh(["tools/full_stats.py"], "6a) 最终统计")
sh(["tools/show_spring.py"], "6b) spring 锚点")
sh(["tools/verify_deliverable.py"], "6c) 交付物总验收")
log("\n=== 夜间流程完成 ===")
LOG.close()
