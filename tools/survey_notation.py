# -*- coding: utf-8 -*-
"""看 GT/曲谱里三连音标记、连音线、圆滑线到底怎么写的 —— 决定解析规则。"""
import collections, glob, io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

files = sorted(glob.glob("train-work/gt/*.txt")) + sorted(glob.glob("D:/Documents_D/jianpu-db/scores/th10_*.txt"))[:4]
pat = collections.Counter()
examples = {}
for f in files:
    try:
        txt = io.open(f, encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    for tok in txt.split():
        # 含括号/波浪/竖线的 token
        if re.search(r"[\[\]()~{}|]", tok):
            pat[tok] += 1
            examples.setdefault(tok, os.path.basename(f))
print("含结构符号的 token(前 30 种):")
for t, c in pat.most_common(30):
    print(f"   {c:5d}  {t!r:16s} 例: {examples[t]}")

print("\n--- 相邻相同数字(=可能是连音线)统计 ---")
for f in files[:6]:
    txt = io.open(f, encoding="utf-8", errors="replace").read()
    toks = [t for t in txt.split() if re.match(r"^[,']*[qsdh]*[,']*[1-7]", t)]
    digs = [re.match(r"^[,']*[qsdh]*[,']*([1-7])", t).group(1) for t in toks]
    run = 0; runs = 0
    for a, b in zip(digs, digs[1:]):
        if a == b:
            run += 1
        else:
            if run:
                runs += 1
            run = 0
    print(f"   {os.path.basename(f)[:34]:36s} 共{len(digs):4d}音, 相邻同音 {runs} 处")
