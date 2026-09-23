# -*- coding: utf-8 -*-
"""自我抽检(批量): 抽若干谱转写 + 渲染带框图 -> 拼图 + token 清单, 供逐张肉眼比对。

抽样策略: 一半随机(无偏), 一半专挑 `x`(念白/读不出)最多的(最可疑)。
输出:
  train-work/qa_batch/拼图.png   —— 各页顶部 45% 的带框图(能看到框落在哪)
  train-work/qa_batch/tokens.txt —— 每页的 token 前 120 个 + 统计
用法: py -3.13 tools/qa_batch.py [每类页数, 默认4]
"""
import glob
import os
import random
import re
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# **不要**设 JP_NOPNG: 本工具要读渲染出来的带框图(第一版就是设了它又去读图 -> FileNotFoundError ✗)
import jp_transcribe as JP
import batch_transcribe as BT
from PIL import Image

N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 4
OUT = "train-work/qa_batch"
os.makedirs(OUT, exist_ok=True)

idx = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        idx[BT.safe_name(os.path.basename(d))] = d

files = [f for f in sorted(glob.glob("batch-out/*.txt"))
         if not os.path.basename(f).startswith("hot_")]
rows = []
for f in files:
    tk = open(f, encoding="utf-8", errors="replace").read().split()
    nx = sum(1 for t in tk if "x" in t)
    rows.append((nx, len(tk), os.path.basename(f)[:-4]))

random.seed(2026)
rand_pick = random.sample(rows, min(N, len(rows)))
worst = sorted(rows, reverse=True)[:N]
picked = rand_pick + worst

lines = []
cells = []
for tag, (nx, ntok, name) in zip(["随机"] * N + ["x最多"] * N, picked):
    d = idx.get(name)
    if not d:
        continue
    try:
        p = BT.pick_page(d)
        if not p:
            continue
        png = os.path.join(OUT, f"_{name[:40]}.png")
        toks, _meta = JP.render(p, png)
        lines.append(f"=== [{tag}] {name}  token {len(toks)}  x {sum(1 for t in toks if 'x' in t)}")
        lines.append("    " + " ".join(toks[:120]))
        lines.append("")
        im = Image.open(png).convert("L")
        c = im.crop((0, 0, im.width, max(60, int(im.height * 0.45))))
        c = c.resize((520, int(c.height * 520 / c.width)), Image.LANCZOS)
        cells.append((tag, name, c))
        os.remove(png)
    except Exception as e:
        lines.append(f"=== [{tag}] {name}  渲染失败 {type(e).__name__}")
        lines.append("")

open(os.path.join(OUT, "tokens.txt"), "w", encoding="utf-8").write("\n".join(lines))

if cells:
    cols = 3
    rows_n = (len(cells) + cols - 1) // cols
    ch = max(c.height for _, _, c in cells)
    sheet = Image.new("L", (520 * cols, ch * rows_n), 255)
    for i, (_t, _n, c) in enumerate(cells):
        sheet.paste(c, ((i % cols) * 520, (i // cols) * ch))
    sheet.save(os.path.join(OUT, "拼图.png"))
    print(f"拼图: {OUT}/拼图.png  {sheet.size}")
print(f"token 清单: {OUT}/tokens.txt  共 {len(cells)} 页")
for tag, name, _ in cells:
    print(f"  [{tag}] {name[:60]}")
