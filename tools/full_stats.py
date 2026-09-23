# -*- coding: utf-8 -*-
"""全量转写统计: 有效/空/跳过/失败 + 音符质量分布。"""
import glob, os, re, sys
from collections import Counter
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")
files = [f for f in glob.glob("batch-out/*.txt")
         if not os.path.basename(f).startswith("hot_")]
print(f"=== 转写文件: {len(files)} ===")

n_ok = n_empty = 0
total_notes = 0
bad_q = bad_x = 0
c_beam = Counter()
c_low = c_voice = c_dot = 0

for f in files:
    tk = open(f, encoding="utf-8").read().split()
    notes = [t for t in tk if NOTE.match(t)]
    if not notes:
        n_empty += 1
        continue
    n_ok += 1
    total_notes += len(notes)
    bad_q += sum(1 for t in tk if "?" in t)
    bad_x += sum(1 for t in tk if "x" in t)
    for t in notes:
        m = re.match(r"^([,']*)([qsdh]*)([,']*)([1-7x0])", t)
        if not m:
            continue
        pre_lo, beam, mid_lo, d = m.groups()
        c_beam[beam] += 1
        c_low += len(pre_lo) + len(mid_lo)
        c_voice += t.count("'")
        c_dot += t.count(".")

print(f"有效(有音符): {n_ok}")
print(f"空/音0:       {n_empty}")
print(f"音符总数:     {total_notes}")
print(f"平均每谱:     {total_notes/max(n_ok,1):.0f}")
print()
print(f"乱码 '?':  {bad_q}")
print(f"念白 'x':  {bad_x}")
print()
print("时值前缀分布(beam):")
for k, v in sorted(c_beam.items(), key=lambda x: -x[1]):
    name = {"": "无(四分)", "q": "q八分", "s": "s十六", "d": "d卅二", "h": "h六四"}.get(k, k)
    print(f"  {name:10s} {v:8d}  ({100*v/max(total_notes,1):5.1f}%)")
print(f"\n低八度点(,): {c_low}")
print(f"高八度点('): {c_voice}")
print(f"附点(.):     {c_dot}")

# 跳过 / 失败
if os.path.exists("batch-out/skipped.txt"):
    sk = open("batch-out/skipped.txt", encoding="utf-8").read().strip().splitlines()
    print(f"\n跳过(超高): {len(sk)}")
for e in ["err.log", "err2.log", "err3.log", "err4.log"]:
    p = f"batch-out/{e}"
    if os.path.exists(p):
        s = open(p, encoding="utf-8", errors="ignore").read()
        n = s.count("Traceback") + s.count("失败")
        if n:
            print(f"{e}: {n} 条异常记录")
