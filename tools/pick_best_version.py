# -*- coding: utf-8 -*-
"""同一首曲子的多个版本（不同来源/不同谱页），挑一个"质量最好/最可信"的。

为什么需要: 一首歌常有多份来自不同站、不同编配的谱, 转写质量参差:
`x`(认不出)比例高的、音符数明显偏少的(截断)、与其它版本差别很大的, 都该被压下去。

评分(v1 启发式, 三项都可解释, 权重写在下面, 可调):
  1) x 率        —— 认不出的音占比, **越低越好**(直接的质量信号)
  2) 共识度      —— 与同组其它版本的**音高袋一致率**取平均, **越高越可信**
                    (多数谱都这么唱 -> 这份大概率没错; 比"信某个站"更硬)
  3) 长度接近度  —— 音符数与组内中位数的接近程度(偏少=截断, 偏多=混入垃圾)

输出: train-work/version_pick.tsv (全组明细) , 并在胜出的 scores 文件里加一行 `preferred=1`。
用法: py -3.13 tools/pick_best_version.py [--apply]
"""
import os
import re
import sys
from collections import Counter, defaultdict

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

APPLY = "--apply" in sys.argv
DIR = "jianpu-db-out/scores"
TOK = re.compile(r"^[,']*[qsdh]*[,']*([0-9x])")


def load(path):
    """-> (音高串(丢八度/休止/x), x 占比, 来源)"""
    txt = open(path, encoding="utf-8", errors="replace").read()
    src = ""
    m = re.search(r"^source=(.+)$", txt, re.M)
    if m:
        src = m.group(1).strip()
    body = txt.split("%--", 1)[-1]
    digs = []
    for t in body.split():
        mm = TOK.match(t)
        if mm:
            digs.append(mm.group(1))
    if not digs:
        return "", 1.0, src
    xr = sum(1 for c in digs if c == "x") / len(digs)
    return "".join(c for c in digs if c not in "x0"), xr, src


def bag(s):
    return Counter(s)


def agree(a, b):
    """音高袋一致率: 1 - |差| / max(长度)"""
    if not a or not b:
        return 0.0
    ca, cb = bag(a), bag(b)
    diff = sum((ca - cb).values()) + sum((cb - ca).values())
    return max(0.0, 1 - diff / max(len(a), len(b)))


groups = defaultdict(list)
for fn in sorted(os.listdir(DIR)):
    if not fn.endswith(".txt"):
        continue
    p = os.path.join(DIR, fn)
    txt = open(p, encoding="utf-8", errors="replace").read(800)
    mt = re.search(r"^title=(.*)$", txt, re.M)
    if not mt:
        continue
    groups[mt.group(1).strip()].append(fn)

multi = {k: v for k, v in groups.items() if len(v) > 1}
print(f"scores {sum(len(v) for v in groups.values())} 份, 曲名 {len(groups)} 个; "
      f"**多版本曲名 {len(multi)} 个**, 涉及文件 {sum(len(v) for v in multi.values())} 个")

rows, picked = [], []
for title, fns in sorted(multi.items(), key=lambda x: -len(x[1])):
    data = {}
    for fn in fns:
        s, xr, src = load(os.path.join(DIR, fn))
        data[fn] = (s, xr, src)
    lens = sorted(len(v[0]) for v in data.values())
    med = lens[len(lens) // 2] or 1
    scored = []
    for fn, (s, xr, src) in data.items():
        others = [v[0] for k, v in data.items() if k != fn]
        cons = sum(agree(s, o) for o in others) / len(others) if others else 1.0
        dev = abs(len(s) - med) / med
        score = 0.5 * cons + 0.3 * max(0.0, 1 - xr / 0.10) + 0.2 * max(0.0, 1 - dev)
        scored.append((score, cons, xr, dev, fn, src, len(s)))
    scored.sort(reverse=True)
    best = scored[0]
    picked.append((title, len(fns), best[4], best[0], best[1], best[2], best[5]))
    for i, (score, cons, xr, dev, fn, src, n) in enumerate(scored):
        rows.append((title, len(fns), "★" if i == 0 else "", fn, round(score, 3),
                     round(cons, 3), round(xr, 3), round(dev, 3), n, src[:40]))

with open("train-work/version_pick.tsv", "w", encoding="utf-8") as f:
    f.write("曲名\t版本数\t选中\t文件\t综合分\t共识度\tx率\t长度偏差\t音符数\t来源\n")
    for r in rows:
        f.write("\t".join(str(x) for x in r) + "\n")

print(f"\n多版本明细 -> train-work/version_pick.tsv（{len(rows)} 行）")
print("\n版本最多的 8 首（看选得对不对）：")
for title, n, fn, score, cons, xr, src in sorted(picked, key=lambda x: -x[1])[:8]:
    print(f"  {n} 版  {title[:18]:20s} 选 {fn[:26]:28s} 分{score:.2f} 共识{cons:.2f} x率{xr:.2f}  [{src[:26]}]")

if APPLY:
    n = 0
    for title, _n, fn, *_ in picked:
        p = os.path.join(DIR, fn)
        txt = open(p, encoding="utf-8", errors="replace").read()
        if re.search(r"^preferred=1$", txt, re.M):
            continue
        txt = re.sub(r"^(source=.*)$", r"\1\npreferred=1", txt, count=1, flags=re.M)
        open(p, "w", encoding="utf-8").write(txt)
        n += 1
    print(f"已在 {n} 份胜出文件里写入 preferred=1")
else:
    print("（只报告；加 --apply 才写 preferred=1）")
