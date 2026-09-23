# -*- coding: utf-8 -*-
"""吸收决定的**后验清理**: 把"数字占比过低"的页移出语料(只移不删)。

依据: 我刚吸收的 667 个"新判据放行"的谱, 实测数字占比中位 77.3% vs 原有语料 78.7%,
      但 **<50% 的占 4.0% vs 原有 1.5%** —— 说明这批里混着一小撮"混排页/五线谱漏网"
      (页面里大量文字/谱线被读成 token, 音符只占一小半)。这类页不该进语料。
判据(保守): ①至少 40 个 token(太短的不判) ②数字占比 < 50% -> 移出。
  注意**不用**"x 率高"判 —— 那条已经被 quarantine_highx 管着, 不重复。
用法: py -3.13 tools/quarantine_lowdigits.py [--apply] [--all]
      --all: 不止清吸收批, 清全语料(现有语料里这类约 1.5%, ~99 份)
产物: train-work/lowdigits_moved.tsv (可逆清单)
"""
import glob
import os
import re
import shutil
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

APPLY = "--apply" in sys.argv
ALL = "--all" in sys.argv
LIST = "train-work/purity2_admit.txt"
THRESH = 0.50
MINTOK = 40


def sid(n):
    m = re.search(r"__([a-z0-9]+-\d+)$", n)
    return m.group(1) if m else ""


WANT_SIDS = {sid(l.strip()) for l in open(LIST, encoding="utf-8") if l.strip()} if os.path.exists(LIST) else set()

rows = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)[:-4]
    if b in ("progress", "skipped"):
        continue
    if not ALL and WANT_SIDS and sid(b) not in WANT_SIDS:
        continue
    t = open(f, encoding="utf-8", errors="replace").read().split()
    if len(t) < MINTOK:
        continue
    dig = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    ratio = dig / len(t)
    if ratio < THRESH:
        rows.append((b, len(t), dig, ratio))

tag = "全语料" if ALL else "吸收批"
print(f"{tag}: 数字占比 <{THRESH:.0%} 且 token>={MINTOK} 的谱 {len(rows)} 份")
for b, n, d, r in sorted(rows, key=lambda x: x[3])[:10]:
    print(f"    {r:.0%}  ({d}/{n})  {b[:52]}")
with open("train-work/lowdigits_moved.tsv", "w", encoding="utf-8") as f:
    f.write("曲名\ttoken\t数字\t数字占比\n")
    for b, n, d, r in rows:
        f.write(f"{b}\t{n}\t{d}\t{r:.3f}\n")
if not APPLY:
    print("(未加 --apply, 只列清单)")
    sys.exit(0)
os.makedirs("batch-out-suspect", exist_ok=True)
n = 0
for b, _n, _d, _r in rows:
    for ext in (".txt", ".png"):
        src = f"batch-out/{b}{ext}"
        if os.path.exists(src):
            shutil.move(src, f"batch-out-suspect/{b}{ext}")
    n += 1
print(f"已移出 {n} 份 -> batch-out-suspect (可逆清单 train-work/lowdigits_moved.tsv)")
