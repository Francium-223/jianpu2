# -*- coding: utf-8 -*-
"""纯度门 JP_PURITY2 小批试点: 抽 40 个"被旧判据拒、新判据应收"的页, 真转一遍。

输出到 train-work/pilot-purity2/ (不写 batch-out, **不碰语料**)。
同时用**同一套统计口径**算已接受语料的基线, 好对比 x 率/0 率(污染代理指标)。

用法: JP_PURITY2=1 py -3.13 tools/pilot_purity2.py [页数, 默认40]
"""
import glob
import os
import random
import re
import statistics
import sys
import time

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("JP_PURITY2", "1")
import jp_transcribe as JP
import batch_transcribe as BT

N = int(sys.argv[1]) if len(sys.argv) > 1 else 40
OUT = "train-work/pilot-purity2"
os.makedirs(OUT, exist_ok=True)
NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")
BADLINE = int(os.environ.get("JP_BADLINE", "5"))
STAFFMAX = int(os.environ.get("JP_STAFFMAX", "4"))


def page_stats(tokens):
    notes = x = zero = q = 0
    for t in tokens:
        if NOTE.match(t):
            notes += 1
            if "x" in t:
                x += 1
            if t.rstrip(".'")[-1] == "0":
                zero += 1
        if "?" in t:
            q += 1
    return len(tokens), notes, x, zero, q


def summarize(label, rows):
    """rows: [(ntok, nnotes, nx, nzero, nq), ...]"""
    if not rows:
        print(f"{label}: 无数据")
        return
    ntok = sum(r[0] for r in rows)
    nnotes = sum(r[1] for r in rows)
    nx = sum(r[2] for r in rows)
    nzero = sum(r[3] for r in rows)
    nq = sum(r[4] for r in rows)
    empty = sum(1 for r in rows if r[1] == 0)
    print(f"{label}  页数 {len(rows)}")
    print(f"  每页音符 中位 {statistics.median(r[1] for r in rows):.0f}  "
          f"均值 {nnotes/len(rows):.1f}")
    print(f"  音符总数 {nnotes}   0 音符的页 {empty} ({100*empty/len(rows):.0f}%)")
    if nnotes:
        print(f"  x 率 {100*nx/nnotes:.2f}%   0 率 {100*nzero/nnotes:.2f}%")
    print(f"  '?' {nq}")


# ---------- 1) 已接受语料基线(同样口径) ----------
base = []
names = [f for f in glob.glob("batch-out/*.txt") if not os.path.basename(f).startswith("hot_")]
random.seed(5)
random.shuffle(names)
for f in names[:200]:
    try:
        tk = open(f, encoding="utf-8", errors="replace").read().split()
    except Exception:
        continue
    base.append(page_stats(tk))

# ---------- 2) 挑试点页 ----------
idx = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        idx[BT.safe_name(os.path.basename(d))] = d
bad = [os.path.basename(f)[:-4] for f in glob.glob("batch-out-bad/*.txt")]
random.seed(11)
random.shuffle(bad)
picked = []
for nm in bad:
    if len(picked) >= N:
        break
    d = idx.get(nm)
    if not d:
        continue
    p = BT.pick_page(d) if True else None
    if not p:
        continue
    try:
        nl, _wd = JP._nline_big(p)
        se = JP._staff_evidence(p)
    except Exception:
        continue
    if nl >= BADLINE and se < STAFFMAX and not JP.is_impure(p):
        picked.append((nm, p, nl, se))
print(f"选中 {len(picked)} 页 (旧判据拒 / 新判据收)\n")

# ---------- 3) 转写 ----------
rows = []
t0 = time.time()
for i, (nm, p, nl, se) in enumerate(picked, 1):
    try:
        toks, _meta = JP.render(p, os.path.join(OUT, f"{i:02d}.png"))
    except Exception as e:
        print(f"  [{i}] 失败 {nm[:36]}: {e}")
        continue
    with open(os.path.join(OUT, f"{i:02d}.txt"), "w", encoding="utf-8") as f:
        f.write(" ".join(toks))
    st = page_stats(toks)
    rows.append(st)
    print(f"  [{i}/{len(picked)}] {nm[:40]:40s} nline={nl:3d} staff={se} "
          f"token {st[0]:4d} 音符 {st[1]:4d} x {st[2]:3d} ({time.time()-t0:.0f}s)", flush=True)

# ---------- 4) 汇总 ----------
print()
summarize("已接受语料基线(200 页):", base)
summarize("试点(新判据放行):", rows)
print(f"\n标注图与 token 在 {OUT}/ (不写 batch-out, 语料未改动)")
