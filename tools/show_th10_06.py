# -*- coding: utf-8 -*-
"""定位查询旋律在 th10_06 里的位置, 并打印前后文。(纯读, 不改仓库)"""
import io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")

p = "D:/Documents_D/jianpu-db/scores/th10_06_expand.txt"
lines = [l.strip() for l in io.open(p, encoding="utf-8").read().splitlines()]
i = next(i for i, l in enumerate(lines) if l.lower().startswith("%--"))
toks = []
for l in lines[i + 1:]:
    if l.startswith("%") or not l:
        continue
    toks += l.split()

digits = []
for t in toks:
    m = re.match(r"^[,']*[qsdh]*[,']*([1-7])", t)
    digits.append(m.group(1) if m else "-")
d = "".join(digits)
q = "33565653253"
pos = d.find(q)
print(f"曲名: 神々が恋した幻想郷 (东方风神录 th10 第6曲, ZUN)")
print(f"总 token {len(toks)};  查询串出现在第 {pos} 个音")
lo, hi = max(0, pos - 8), min(len(toks), pos + len(q) + 8)
print("\n带时值的前后文:")
print("  " + " ".join(toks[lo:pos]) + "  【" + " ".join(toks[pos:pos + len(q)]) + "】  "
      + " ".join(toks[pos + len(q):hi]))
print("\n开头 24 个 token:")
print("  " + " ".join(toks[:24]))
