# -*- coding: utf-8 -*-
"""质量度量: 比较语料与 GT 的八度标记率/时值分布, 看是否有系统性偏差。"""
import glob, os, re, sys, collections
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def stats(toks):
    n = len(toks) or 1
    low = sum(1 for t in toks if "," in t)
    high = sum(1 for t in toks if "'" in t)
    beam = collections.Counter()
    for t in toks:
        m = re.match(r"^([qsdh]*)", t)
        beam[m.group(1) if m else ""] += 1
    dot = sum(1 for t in toks if "." in t)
    return dict(n=n, low=low / n, high=high / n, dot=dot / n,
                q=beam.get("q", 0) / n, s=beam.get("s", 0) / n,
                d=beam.get("d", 0) / n, h=beam.get("h", 0) / n, none=beam.get("", 0) / n)

# 语料
allt = []
for f in glob.glob("batch-out/*.txt"):
    if os.path.basename(f) in ("progress.txt", "skipped.txt"):
        continue
    allt += open(f, encoding="utf-8").read().split()
cs = stats(allt)
print(f"语料 {cs['n']} token:")
print(f"  低八度 {cs['low']*100:5.1f}%   高八度 {cs['high']*100:5.1f}%   附点 {cs['dot']*100:5.1f}%")
print(f"  四分 {cs['none']*100:5.1f}%  八分 {cs['q']*100:5.1f}%  十六 {cs['s']*100:5.1f}%  "
      f"三二 {cs['d']*100:5.1f}%  六四 {cs['h']*100:5.1f}%")

# GT
def gt_tokens(p):
    t = open(p, encoding="utf-8", errors="replace").read()
    lines = [l.strip() for l in t.splitlines()]
    if any(l.lower().startswith("%--") for l in lines):
        i = next(i for i, l in enumerate(lines) if l.lower().startswith("%--"))
        lines = lines[i + 1:]
    s = " ".join(lines).replace("(", " ").replace(")", " ")
    return [x for x in s.split() if x == "-" or re.match(r"^[,']*[qsdh#b]*[,']*[1-7x0][.,'qsdh#b-]*$", x)]

for g in ["春天在哪里", "小星星", "澎湖湾_用户", "Lemon_用户"]:
    p = f"train-work/gt/{g}.txt"
    if not os.path.exists(p):
        continue
    t = gt_tokens(p)
    if not t:
        continue
    gs = stats(t)
    print(f"\nGT {g} ({gs['n']} token):")
    print(f"  低八度 {gs['low']*100:5.1f}%   高八度 {gs['high']*100:5.1f}%   附点 {gs['dot']*100:5.1f}%")
    print(f"  四分 {gs['none']*100:5.1f}%  八分 {gs['q']*100:5.1f}%  十六 {gs['s']*100:5.1f}%  "
          f"三二 {gs['d']*100:5.1f}%  六四 {gs['h']*100:5.1f}%")
