# -*- coding: utf-8 -*-
"""自我抽检: 随机抽 N 首, 把"谱图前几行"和"转写出的 token"并排放在一个 HTML 里, 供人眼核对。

为什么这么设计: 转写正确率不能只靠自己报数字, 得能**逐条复核**。把图像裁剪和 token 放在
同一张表里, 人扫一眼就能看出"这一行的数字读没读对"。纯 CPU(只用几何切行 + 已有的 txt),
不需要 GPU, 所以随时能跑。

用法: py -3.13 tools/qa_sample.py [N=40] [--site jianpucn|qupu123|jianpujia|all]
产物: train-work/qa_sample/<曲名>.png + train-work/qa_sample/index.html
"""
import glob
import html
import io
import os
import random
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
from PIL import Image
import numpy as np
import transcribe as T
import batch_transcribe as BT

ARGS = sys.argv[1:]
N = int(ARGS[0]) if ARGS and ARGS[0].isdigit() else 40
SITE = ARGS[ARGS.index("--site") + 1] if "--site" in ARGS else "all"
# --names <文件>: 只从这个名单(每行一个目录名/曲名)里抽 —— 用来单独抽查某一批
# (例如刚吸收的"新纯度判据放行"的那 667 个, 看它们质量是不是真和基线一致)
NAMES = ARGS[ARGS.index("--names") + 1] if "--names" in ARGS else ""
SEED = int(ARGS[ARGS.index("--seed") + 1]) if "--seed" in ARGS else 20260922
OUT = "train-work/qa_sample"
os.makedirs(OUT, exist_ok=True)

WANT = None
if NAMES and os.path.exists(NAMES):
    WANT = {l.strip() for l in open(NAMES, encoding="utf-8") if l.strip()}
    print(f"只从名单里抽: {NAMES} ({len(WANT)} 条)")


def find_dir(name):
    for d in glob.glob("images-prep/*/*"):
        if os.path.isdir(d) and BT.safe_name(os.path.basename(d)) == name:
            return d
    return None


def site_of(name):
    m = re.search(r"__([a-z0-9]+)-\d+$", name)
    return m.group(1) if m else "?"


pool = []
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)[:-4]
    if b in ("progress", "skipped"):
        continue
    if SITE != "all" and site_of(b) != SITE:
        continue
    if WANT is not None and b not in WANT:
        continue
    try:
        toks = io.open(f, encoding="utf-8").read().split()
    except Exception:
        continue
    if len(toks) < 20:              # 太短的没看头
        continue
    pool.append((b, toks))
rnd = random.Random(SEED)
rnd.shuffle(pool)

rows = []
for name, toks in pool:
    if len(rows) >= N:
        break
    d = find_dir(name)
    if not d:
        continue
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        im = Image.open(p).convert("RGB")
        if im.width > 2000:
            im = im.resize((2000, int(im.height * 2000 / im.width)), Image.LANCZOS)
        elif im.width < 950:
            im = im.resize((1200, int(im.height * 1200 / im.width)), Image.LANCZOS)
        g = np.asarray(im.convert("L")) < T.TOL
        bands = list(T.fine_rows(g, T.ROW_GAP))
        y1 = bands[2][1] if len(bands) >= 3 else (bands[0][1] if bands else im.height // 3)
        crop = im.crop((0, 0, im.width, min(im.height, y1 + 10)))
        if crop.width > 1500:
            crop = crop.resize((1500, int(crop.height * 1500 / crop.width)), Image.LANCZOS)
        fn = BT.safe_name(name)[:52].replace("/", "_") + ".png"
        crop.save(os.path.join(OUT, fn))
    except Exception as ex:
        print(f"  {name[:30]}: 裁图失败 {type(ex).__name__}")
        continue
    ndig = sum(1 for t in toks
               if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    rows.append({"name": name, "png": fn, "site": site_of(name), "ntok": len(toks),
                 "ndig": ndig, "text": " ".join(toks[:90]) + (" …" if len(toks) > 90 else "")})
    print(f"  [{len(rows)}/{N}] {name[:44]:<46} token {len(toks)} 数字 {ndig}")

H = ["<html><head><meta charset='utf-8'><title>jianpu2 抽检</title>",
     "<style>body{font-family:system-ui,'Microsoft YaHei';margin:16px;background:#fafafa}",
     "table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:6px;vertical-align:top}",
     "img{max-width:640px;border:1px solid #ccc}code{font-size:12px;word-break:break-all}",
     "tr:nth-child(even){background:#fff}</style></head><body>",
     f"<h2>jianpu2 抽检样本 {len(rows)} 首（随机, 种子 {SEED}, 站点 {SITE}）</h2>",
     "<p>看每行：左边是原谱前 3 个行带，右边是转写出的 token。**数字读没读对，肉眼一比就知道**。"
     "发现错的，把曲名记下来交给 <code>tools/qa_check.py</code> 细看。</p>",
     "<table><tr><th>#</th><th>曲名</th><th>站点</th><th>谱图（前 3 行带）</th>"
     "<th>token（前 90 个）</th><th>规模</th></tr>"]
for i, r in enumerate(rows, 1):
    H.append(f"<tr><td>{i}</td><td>{html.escape(r['name'][:60])}</td><td>{r['site']}</td>"
             f"<td><img src='{html.escape(r['png'])}'></td>"
             f"<td><code>{html.escape(r['text'])}</code></td>"
             f"<td>token {r['ntok']}<br>数字 {r['ndig']}</td></tr>")
H.append("</table></body></html>")
with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
    f.write("\n".join(H))
print(f"\n-> {OUT}/index.html  ({len(rows)} 首)")
