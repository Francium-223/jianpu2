# -*- coding: utf-8 -*-
"""把非纯简谱的转写结果移出语料到 batch-out-bad/(隔离, 不删)。
用法: py tools/apply_kind_filter.py [--dry]

**本步只对"本轮判定变化的"做事**: 已在 batch-out-bad 的目录查不到文件 -> 直接跳过。
2026-10-07 之前每个非纯目录都要 `glob.glob("batch-out/*<id>.txt")` 一次去确认它不在,
2.1 万个非纯行 → 每行一次全目录枚举 → 实测 30 分钟。现在索引 `batch-out` **一次**, 之后全是
字典查询; 查不到就是"已经移出过", 与旧行为同义(旧代码找不到也什么都不做)。
"""
import csv, glob, os, re, shutil, sys
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

DRY = "--dry" in sys.argv
rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
bad = [r for r in rows if r["pure"] == "0"]
print(f"非纯简谱 {len(bad)} 个")
os.makedirs("batch-out-bad", exist_ok=True)

# batch-out 索引: 全名 -> 路径; 以及"站-id 后缀 -> 路径"(旧代码的 glob 回退分支)。
# glob 的返回顺序 = 目录枚举顺序, 取 [0] 等价于取枚举到的第一个同后缀文件 —— 这里照做。
by_name, by_id = {}, {}
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    by_name[b[:-4]] = f
    m = re.search(r"([A-Za-z]+\d*-\d+)$", b[:-4])
    if m:
        by_id.setdefault(m.group(1), []).append(f)

def find(d):
    nm = BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if os.path.exists(f):
        return f
    m = re.search(r"([A-Za-z]+\d*-\d+)$", d)
    if m:
        g = by_id.get(m.group(1))
        if g:
            return g[0]
    return None

moved = notes = 0
for r in bad:
    f = find(r["dir"])
    if not f:
        continue
    t = open(f, encoding="utf-8").read().split()
    n = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    notes += n
    moved += 1
    if not DRY:
        shutil.move(f, os.path.join("batch-out-bad", os.path.basename(f)))
        png = f[:-4] + ".png"
        if os.path.exists(png):
            shutil.move(png, os.path.join("batch-out-bad", os.path.basename(png)))
print(f"{'[dry] ' if DRY else ''}移出 {moved} 个结果, 带走音符 {notes}")
