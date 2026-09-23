# -*- coding: utf-8 -*-
"""测不同 batch size 的吞吐(用同一批已转写的谱, 重转计时)。"""
import glob, os, random, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
# 挑 12 个中等大小的谱
cand = []
for f in files:
    n = len(open(f, encoding="utf-8").read().split())
    if 100 <= n <= 220:
        cand.append(f)
random.seed(3)
picks = random.sample(cand, min(12, len(cand)))
imgs = []
for f in picks:
    name = os.path.basename(f)[:-4]
    hits = [p for p in glob.glob("images-prep/*/" + glob.escape(name)) if os.path.isdir(p)]
    if hits:
        p = BT.pick_page(hits[0])
        if p:
            imgs.append(p)
print(f"测试 {len(imgs)} 个谱, batch={os.environ.get('JP_BATCH')}")
import jp_transcribe as JP
JP._init()
t0 = time.time()
tot = 0
for p in imgs:
    toks, _ = BT.transcribe_paged(p, "train-work/_b.txt", "train-work/_b.png")
    tot += len(toks)
el = time.time() - t0
print(f"耗时 {el:.1f}s  ({el/len(imgs):.2f}s/谱, token 合计 {tot})")
