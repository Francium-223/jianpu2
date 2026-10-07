# -*- coding: utf-8 -*-
"""收尾流水线(一次跑完):
  1) 重新扫描全库纯度 (kind_detect2)          -> kind2.tsv   [增量: 只重量输入变了的目录]
  2) 非纯简谱结果移出到 batch-out-bad/        (隔离, 不删)
  3) 版本择优 (pick_best)                     -> drop_dup.txt
  4) 同名的落选版本移出到 batch-out-dup/
  5) 重建 jianpu-db scores (to_jianpu_db)
  6) 下游 parse_scores + db_to_jsonl (在 train-work/jpdbtest 副本上)
用法: py tools/finalize.py [--skip-scan] [--full]

定常成本账(2026-10-07 实测, 一趟 3h19m 里 165 分钟是"与转写互斥"的那段):
  ① kind_detect2 81 分钟(其中 measure 逐页读图重算 73 分钟)
  + apply_kind_filter 30 分钟(2.1 万个非纯行, 每行一次 batch-out 全目录 glob)
  + pick_best 54 分钟(4.7 万个目录, 每个一次 batch-out 全目录 glob 去数音符)
  三处都改成"输入变了才算" + "目录只枚举一次": 见 tools/kind2_cache.py 与各脚本头部。
"""
import os, shutil, subprocess, sys, time
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
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
    # 增量: kind_detect2 只重量"目录/谱页变过"的目录(判据见 tools/kind2_cache.py);
    # `--full` 才退回全量重扫。结论与全量重扫逐字节一致, 见 kind2_cache 的模块说明。
    run(["tools/kind_detect2.py"] + (["--full"] if "--full" in sys.argv else []), "1) 扫描纯度")
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
# batch-out 索引**建一次**: 原来每个落选目录都要 `glob.glob("batch-out/*id.txt")` 枚举一遍整个
# 目录(1.6 万个落选 × 2.7 万个文件 = 纯浪费)。这里改成一次枚举 + 字典查询, 语义不变:
# 先试精确路径, 再退回"按站-id 后缀"的旧 glob 分支(取 glob 顺序里的第一个)。
_FILES = glob.glob("batch-out/*.txt")
_BY_ID = {}
for _f in _FILES:
    _m = re.search(r"([A-Za-z]+\d*-\d+)$", os.path.basename(_f)[:-4])
    if _m:
        _BY_ID.setdefault(_m.group(1), []).append(_f)
n = 0
for line in open("train-work/drop_dup.txt", encoding="utf-8"):
    d = line.strip()
    if not d:
        continue
    nm = BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        m = re.search(r"([A-Za-z]+\d*-\d+)$", d)
        g = _BY_ID.get(m.group(1), []) if m else []
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
# `--stable`: 上面刚把旧成品整体移到 scores-prev, 输出目录是空的 -> 若不"对号入座", 新谱会按 sorted
# 顺序**抢走旧名**(实测 2026-09-28 07:16 那次: 165 首新谱抢名 / 178 首老谱被迫改名), 而导入是"只拷不覆盖"
# -> 抢名的新歌被丢掉、改名后的老歌被再拷一份(实测 76 首白转)。
# `--stable-from scores-prev` 让每份老谱按**内容**认回自己的名字, 新谱只能躲到 _2/_3。
# 对不上号/出任何错时 to_jianpu_db 会自己退回普通命名, 不会让这一步失败。
run(["tools/to_jianpu_db.py", "--meter", "--stable", "--stable-from", "jianpu-db-out/scores-prev",
     "--transcriber", "jianpu2-auto"], "5) 重建 scores")
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
