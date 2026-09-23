# -*- coding: utf-8 -*-
"""盘点"还没转写"的谱目录，并分出"纯度门挡掉的"和"真的能转的"。

背景: images-prep 里 15129 个目录, 但 batch-out 只有 ~6460 个 txt。差额里绝大多数是
**纯度门挡掉的非纯谱**(挡掉时不写 txt, 所以看着像"没转"), 但可能混着真正漏掉的纯简谱。
判据用 jp_transcribe.is_impure(与管线**同一个函数**, 不另写一份 ✗)。

输出:
  train-work/backlog_pure.txt    —— 真能转的(纯简谱且无结果) -> 可直接喂 transcribe_source.py
  train-work/backlog_impure.txt  —— 纯度门挡掉的(非纯, 不该转)
用法: py -3.13 tools/scan_backlog.py [限制数]
"""
import glob
import os
import sys
import time

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import batch_transcribe as BT
import jp_transcribe as JP

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0

dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
print(f"images-prep 谱目录: {len(dirs)}", flush=True)

# **只看 batch-out 是错的** ✗ —— finalize 会把结果**移出** batch-out:
#   重复内容 -> batch-out-dup, 混排/非纯 -> batch-out-bad, 认不出音符 -> batch-out-empty,
#   质量可疑 -> batch-out-suspect。
# 这些源目录在 batch-out 里当然找不到结果, 于是被判成"没转过"重新排队, 转完又被移走,
# 下一轮再排 —— 无限空转。实测 2026-09-21 那轮: 名单去重后 2252 条里 **1900 条(84.4%)**
# 在 -dup/-bad/-empty/-suspect 里已有结果(抽样的 SHA256 与重转结果逐字节相同), 白烧 ~10 小时 GPU。
# 所以"已处理"必须把这四个目录一起算上。
RESULT_DIRS = ["batch-out", "batch-out-dup", "batch-out-bad",
               "batch-out-empty", "batch-out-suspect"]
done_names, done_by = set(), {}
for _rd in RESULT_DIRS:
    # JP_RETRY_EMPTY=1 时把空结果排除在"已处理"之外(改了识别器想重试时才用)
    if _rd == "batch-out-empty" and os.environ.get("JP_RETRY_EMPTY") == "1":
        continue
    for f in glob.glob(f"{_rd}/*.txt"):
        b = os.path.basename(f)[:-4]
        done_names.add(b)
        done_by.setdefault(b, _rd)
print(f"已有结果的曲目名(含 -dup/-bad/-empty/-suspect): {len(done_names)}", flush=True)

todo, _seen, _collide = [], set(), 0
for d in dirs:
    sn = BT.safe_name(os.path.basename(d))
    if sn in done_names:
        continue
    if sn in _seen:          # 两个不同源目录映射到同一个输出名 -> 后者会覆盖前者, 只留一个
        _collide += 1
        continue
    _seen.add(sn)
    todo.append(d)
print(f"没有转写结果的: {len(todo)}  (同名塌缩跳过 {_collide})", flush=True)
if LIMIT:
    todo = todo[:LIMIT]
    print(f"本次只查前 {LIMIT} 个", flush=True)

pure, impure, nopage, err = [], [], 0, 0
t0 = time.time()
for i, d in enumerate(todo, 1):
    try:
        p = BT.pick_page(d)
        if not p:
            nopage += 1
            continue
        if JP.is_impure(p):
            impure.append(os.path.basename(d.rstrip("/\\")))
        else:
            pure.append(os.path.basename(d.rstrip("/\\")))
    except Exception:
        err += 1
    if i % 500 == 0:
        el = time.time() - t0
        print(f"  {i}/{len(todo)}  能转 {len(pure)}  非纯 {len(impure)}  "
              f"({el/i:.2f}s/个, 预计还要 {(len(todo)-i)*el/i/60:.0f} 分钟)", flush=True)

def _uniq(seq):
    out, seen = [], set()
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


pure, impure = _uniq(pure), _uniq(impure)
open("train-work/backlog_pure.txt", "w", encoding="utf-8").write("\n".join(pure) + "\n")
open("train-work/backlog_impure.txt", "w", encoding="utf-8").write("\n".join(impure) + "\n")
print(f"\n能转(纯简谱、无结果): {len(pure)}  -> train-work/backlog_pure.txt")
print(f"非纯(纯度门该挡):     {len(impure)}  -> train-work/backlog_impure.txt")
print(f"无谱页 {nopage}   异常 {err}   耗时 {(time.time()-t0)/60:.0f} 分钟")
