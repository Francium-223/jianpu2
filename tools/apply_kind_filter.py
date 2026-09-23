# -*- coding: utf-8 -*-
"""把非纯简谱的转写结果移出语料到 batch-out-bad/(隔离, 不删)。
用法: py tools/apply_kind_filter.py [--dry]
"""
import csv, glob, os, re, shutil, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

DRY = "--dry" in sys.argv
rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
bad = [r for r in rows if r["pure"] == "0"]
print(f"非纯简谱 {len(bad)} 个")
os.makedirs("batch-out-bad", exist_ok=True)

def find(d):
    nm = BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if os.path.exists(f):
        return f
    m = re.search(r"([A-Za-z]+\d*-\d+)$", d)
    if m:
        g = glob.glob(f"batch-out/*{glob.escape(m.group(1))}.txt")
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
