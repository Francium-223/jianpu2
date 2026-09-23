# -*- coding: utf-8 -*-
"""语料 QA: 找异常(空谱/极低密度/乱码/异常长 token 等), 纯 CPU。"""
import collections, glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def digits_of(toks):
    n = 0
    for x in toks:
        c = x.lstrip("qsdh,").rstrip("'.")
        if c and c[-1] in "1234567":
            n += 1
    return n

fs = [f for f in glob.glob("batch-out/*.txt")
      if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
empty, low, high, bad_chars, weird = [], [], [], [], []
tot = 0
for f in fs:
    try:
        toks = open(f, encoding="utf-8").read().split()
    except Exception:
        bad_chars.append(f); continue
    d = digits_of(toks)
    tot += d
    if d == 0:
        empty.append(f)
    elif d < 10:
        low.append((d, f))
    elif d > 900:
        high.append((d, f))
    for t in toks:
        if not re.fullmatch(r"[qsdh]*[,']*[1-7x0]\.*|[-0]", t):
            weird.append((t, os.path.basename(f)))
            break

print(f"语料 {len(fs)} 个, 音符合计 {tot}")
print(f"\n空谱(0 音符): {len(empty)}")
print(f"极少(1-9):    {len(low)}")
print(f"异常多(>900):  {len(high)}")
print(f"读不出的文件: {len(bad_chars)}")
print(f"格式异常的 token: {len(set(w for w,_ in weird))} 种")
for t, f in weird[:8]:
    print(f"    {t!r}  例: {f[:40]}")
print("\n音符最多的前 5:")
for d, f in sorted(high, reverse=True)[:5]:
    print(f"    {d:4d}  {os.path.basename(f)[:46]}")
print("\n空谱样例:")
for f in empty[:6]:
    print(f"    {os.path.basename(f)[:46]}")

# 自检结果落盘(交付说明要并进去, 不能只留在屏幕/日志里)
W = len(set(w for w, _f in weird))
with open("train-work/qa_report.txt", "w", encoding="utf-8") as f:
    f.write(f"语料 {len(fs)} 个, 音符合计 {tot}\n")
    f.write(f"空谱(0音符) {len(empty)} / 极少(1-9) {len(low)} / 异常多(>900) {len(high)} / "
            f"读不出 {len(bad_chars)} / 格式异常 token {W} 种\n")
    if bad_chars:
        f.write("读不出的文件(前10): " + "、".join(os.path.basename(x) for x in bad_chars[:10]) + "\n")
    if weird:
        f.write("格式异常 token 样例: " + "、".join(repr(t) for t, _f in weird[:10]) + "\n")
    if high:
        f.write("音符最多: " + "、".join(f"{d}({os.path.basename(x)[:26]})"
                                        for d, x in sorted(high, reverse=True)[:5]) + "\n")
print("\n-> train-work/qa_report.txt")
