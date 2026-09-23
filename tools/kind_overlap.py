# -*- coding: utf-8 -*-
"""交叉: 非纯简谱里有多少已有转写结果(需从语料剔除)。"""
import csv, glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

rows = list(csv.DictReader(open("train-work/kind_final.tsv", encoding="utf-8"), delimiter="\t"))
bad = [r for r in rows if r["pure"] == "0"]
print(f"非纯简谱 {len(bad)} 个")

def outfile(d):
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

have = []
for r in bad:
    f = outfile(r["dir"])
    if f:
        t = open(f, encoding="utf-8").read().split()
        n = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        have.append((r["dir"], f, n, int(r["nline_big"])))
print(f"其中已有转写结果的: {len(have)}")
print(f"  音符>=10 的(真污染): {sum(1 for _,_,n,_ in have if n>=10)}")
print(f"  音符总污染量: {sum(n for _,_,n,_ in have)}")
with open("train-work/bad_sheets.txt", "w", encoding="utf-8") as g:
    for d, f, n, nb in have:
        g.write(f"{d}\t{f}\t{n}\t{nb}\n")
print("名单 -> train-work/bad_sheets.txt")
print("\n污染最重的前 12 个:")
for d, f, n, nb in sorted(have, key=lambda x: -x[2])[:12]:
    print(f"   音符{n:4d} nline_big={nb:3d}  {d[:44]}")
