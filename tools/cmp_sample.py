# -*- coding: utf-8 -*-
"""逐谱对比: 从已转写的 batch-out 随机抽 40 个, 新代码重转 vs 旧结果。"""
import glob, os, random, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

def stat(toks):
    d = x = dot = 0
    for t in toks:
        core = t.lstrip("qsdh,").rstrip("'.")
        if core and core[-1] in "1234567":
            d += 1
        if "x" in t:
            x += 1
        if "." in t:
            dot += 1
    return len(toks), d, x, dot

files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
random.seed(7)
random.shuffle(files)
print(f"{'谱名':30s} {'旧音':>5s} {'新音':>5s} {'旧数':>5s} {'新数':>5s} {'新x':>4s} {'新附':>4s}")
n = 0
bad = []
for f in files:
    if n >= 40:
        break
    name = os.path.basename(f)[:-4]
    hits = [p for p in glob.glob("images-prep/*/" + glob.escape(name)) if os.path.isdir(p)]
    if not hits:
        continue
    page = BT.pick_page(hits[0])
    if not page:
        continue
    try:
        toks, _ = BT.transcribe_paged(page, "train-work/_c.txt", "train-work/_c.png")
    except Exception as ex:
        print(f"{name[:30]:30s} 失败 {type(ex).__name__}")
        continue
    olds = open(f, encoding="utf-8").read().split()
    on, od, _, _ = stat(olds)
    nn, nd, nx, ndot = stat(toks)
    n += 1
    print(f"{name[:30]:30s} {on:5d} {nn:5d} {od:5d} {nd:5d} {nx:4d} {ndot:4d}")
    if on >= 20 and nd < 0.6 * od:
        bad.append((name, od, nd))
print(f"\n对比 {n} 谱; 数字减少 >40%:", bad if bad else "无")
