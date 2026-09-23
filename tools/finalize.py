# -*- coding: utf-8 -*-
"""收尾流水线(一次跑完):
  1) 重新扫描全库纯度 (kind_detect2)          -> kind2.tsv
  2) 非纯简谱结果移出到 batch-out-bad/        (隔离, 不删)
  3) 版本择优 (pick_best)                     -> drop_dup.txt
  4) 同名的落选版本移出到 batch-out-dup/
  5) 重建 jianpu-db scores (to_jianpu_db)
  6) 下游 parse_scores + db_to_jsonl (在 train-work/jpdbtest 副本上)
用法: py tools/finalize.py [--skip-scan]
"""
import os, shutil, subprocess, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

PY = sys.executable

def run(args, label):
    t0 = time.time()
    print(f"\n=== {label} ===", flush=True)
    r = subprocess.run([PY] + args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = (r.stdout or "").strip().splitlines()[-3:]
    for l in tail:
        print("   " + l)
    if r.returncode != 0:
        print("   [失败] " + (r.stderr or "").strip().splitlines()[-1:][0] if r.stderr else "   [失败]")
    print(f"   ({time.time()-t0:.0f}s)")
    return r.returncode

SKIP_SCAN = "--skip-scan" in sys.argv
if not SKIP_SCAN:
    run(["tools/kind_detect2.py"], "1) 扫描纯度")
else:
    print("跳过扫描(用现有 kind2.tsv)")

run(["tools/apply_kind_filter.py"], "2) 移出非纯简谱")
run(["tools/quarantine_highx.py"], "2b) 移出高念白率谱(纯度门漏网的安全网)")
run(["tools/quarantine_empty.py"], "2c) 移出 0 音符结果(五线谱漏网/转写失败)")
run(["tools/pick_best.py"], "3) 版本择优")

# 4) 落选版本移出
os.makedirs("batch-out-dup", exist_ok=True)
import glob, re
import batch_transcribe as BT
n = 0
for line in open("train-work/drop_dup.txt", encoding="utf-8"):
    d = line.strip()
    if not d:
        continue
    nm = BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        m = re.search(r"([A-Za-z]+\d*-\d+)$", d)
        g = glob.glob(f"batch-out/*{glob.escape(m.group(1))}.txt") if m else []
        f = g[0] if g else None
    if f and os.path.exists(f):
        shutil.move(f, os.path.join("batch-out-dup", os.path.basename(f)))
        png = f[:-4] + ".png"
        if os.path.exists(png):
            shutil.move(png, os.path.join("batch-out-dup", os.path.basename(png)))
        n += 1
print(f"\n=== 4) 落选版本移出 {n} 个 ===")

# 5) 重建 scores
# **必须先清空输出目录**: to_jianpu_db 只写不删, 旧文件会和新文件堆在一起 ——
# 实测出现 2604 个 scores 而语料只有 2022 个, 也就是交付物里混着已隔离/已删歌曲的残留。
# 但**不能直接删**(2026-09-22 改): 旧文件里有①已认过的拍号 ②人工打的 `todo=` / `preferred=`。
# 删掉 = 每次重建都要对 6000+ 份谱重跑模型认拍号(~50 分钟 GPU), 人工标记也全丢。
# 改成移到 `jianpu-db-out/scores-prev/`, 由 to_jianpu_db 去那里复用。
PREV = "jianpu-db-out/scores-prev"
if os.path.isdir(PREV):
    shutil.rmtree(PREV, ignore_errors=True)
os.makedirs(PREV, exist_ok=True)
_n_old = 0
for _f in glob.glob("jianpu-db-out/scores/*.txt"):
    try:
        shutil.move(_f, os.path.join(PREV, os.path.basename(_f)))
        _n_old += 1
    except Exception:
        pass
if _n_old:
    print(f"\n=== 5) 旧 scores 移到 scores-prev ({_n_old} 个, 供拍号/人工标记复用) ===")
run(["tools/to_jianpu_db.py", "--meter", "--transcriber", "jianpu2-auto"], "5) 重建 scores")
run(["tools/make_source_map.py"], "5b) 生成来源映射表(旁路, 供溯源)")

# 6) 下游(副本, 不动用户的 jianpu-db 仓库)
J = "train-work/jpdbtest"
os.makedirs(f"{J}/scores", exist_ok=True)
for f in glob.glob(f"{J}/scores/*"):
    os.remove(f)
for f in glob.glob("jianpu-db-out/scores/*.txt"):
    shutil.copy(f, f"{J}/scores/")
print("\n=== 6) 下游 ===")
r = subprocess.run([PY, "parse_scores.py"], cwd=J, capture_output=True, text=True, encoding="utf-8", errors="replace")
if r.stdout:
    print("   " + r.stdout.strip().splitlines()[-1])
r = subprocess.run([PY, "db_to_jsonl.py", "out.jsonl"], cwd=J, capture_output=True, text=True, encoding="utf-8", errors="replace")
for l in (r.stdout or "").strip().splitlines()[:3]:
    print("   " + l)
print("\n收尾完成")
