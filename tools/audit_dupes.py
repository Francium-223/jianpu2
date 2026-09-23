# -*- coding: utf-8 -*-
"""语料体检: 不同曲名但**旋律完全相同**的谱(内容级重复)。

为什么要查: 交付要求里有一条"同名取最优版本", `pick_best.py` 是按**曲名**归并的;
但同一个源站常把同一首歌用**不同曲名**挂两次(`稻香` / `稻香（稻香）`), 曲名不同就绕过了归并,
语料里于是留下两份一模一样的旋律 —— 会虚高规模, 还会在检索评测里互相"抢名次"。

做法: 把每份谱压成"音高串"(丢八度/休止/认不出的块, 与检索评测同一口径), 按**整串**分组;
长度都 >= 40 音才算。分三个数报告:
  * 完全相同的总份数(含已归并到 batch-out-dup 的)
  * **仍留在 batch-out 的重复组** <- 这是 pick_best 没覆盖到的、可安全去重的
  * 前 N 个音相同但整串不同的(疑似同曲不同编配, 只列表不判重)

用法: py -3.13 tools/audit_dupes.py [前几个音=60]
产物: train-work/dup_melodies.tsv
"""
import glob
import os
import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
import melody_oct as M

PRE = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 60
SKIP = "0x"


def pitch_of(txt):
    e, _raw = M.enc(txt)
    return "".join(x[0] for x in e if x[0] not in SKIP)


recs = []           # (name, ndig, pitch, result_dir)
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        d = pitch_of(open(f, encoding="utf-8", errors="replace").read())
        if len(d) < 40:
            continue
        recs.append((os.path.basename(f)[:-4], len(d), d, os.path.dirname(f)))
print(f"参与体检的谱 {len(recs)} 份(>=40 音)")

by_full = defaultdict(list)
by_pre = defaultdict(list)
for r in recs:
    by_full[r[2]].append(r)
    by_pre[r[2][:PRE]].append(r)

hard = {k: v for k, v in by_full.items() if len(v) > 1}
loose = {k: v for k, v in by_pre.items() if len(v) > 1}
hard_n = sum(len(v) for v in hard.values())
print(f"**整串完全相同**的: {len(hard)} 组 / {hard_n} 份")

live = []
for k, v in hard.items():
    inb = [r for r in v if r[3] == "batch-out"]
    if len(inb) > 1:
        live.append(inb)
print(f"**仍留在 batch-out(未被 pick_best 归并)** 的重复组: {len(live)} 组 / "
      f"{sum(len(x) for x in live)} 份  <- 这些是可安全去重的")
print(f"前 {PRE} 音相同但整串不同的(疑似同曲不同编配): {len(loose)} 组 / "
      f"{sum(len(v) for v in loose.values())} 份 (只列清单, 不判重)")

with open("train-work/dup_melodies.tsv", "w", encoding="utf-8") as f:
    f.write("类型\t组号\t曲名\t音符数\t所在目录\n")
    # ①先写"已归并"的: batch-out 里留一份, 其余在 -dup —— 这就是去重清单的**重建**(清单丢不了)
    i = 0
    for k, v in sorted(hard.items(), key=lambda kv: -len(kv[1])):
        inb = [r for r in v if r[3] == "batch-out"]
        ind = [r for r in v if r[3] != "batch-out"]
        if not inb or not ind:
            continue
        i += 1
        f.write(f"同名重复-保留\t{i}\t{inb[0][0]}\t{inb[0][1]}\tbatch-out\n")
        for r in ind:
            f.write(f"同名重复-已归并\t{i}\t{r[0]}\t{r[1]}\t{r[3]}\n")
    for i, v in enumerate(sorted(live, key=lambda x: -len(x)), 1):
        for r in sorted(v, key=lambda x: -x[1]):
            f.write(f"完全重复-仍在batch-out\t{i}\t{r[0]}\t{r[1]}\t{r[3]}\n")
    for i, v in enumerate(sorted(loose.values(), key=lambda x: -len(x)), 1):
        for r in sorted(v, key=lambda x: -x[1])[:8]:
            f.write(f"疑似同曲不同编配\t{i}\t{r[0]}\t{r[1]}\t{r[3]}\n")
print("-> train-work/dup_melodies.tsv  (含'已归并'对应关系, 即使去重清单被覆盖也能重建)")
for v in sorted(live, key=lambda x: -len(x))[:6]:
    print(f"   [{len(v)} 份] " + " | ".join(r[0][:32] for r in v[:4]))
