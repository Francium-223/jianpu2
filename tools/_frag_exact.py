# -*- coding: utf-8 -*-
"""严格口径重做: 用检索器真正的编码(音级+八度) 查 3565321232176 在库里的精确命中。

三种口径都要报, 免得再犯"用自己的宽松口径下结论"的错:
  A 音级 only        (丢八度)                —— 上一版用的, 偏宽松
  B 音级+八度        (检索器实际用的)          —— 唯一作数的
  C 音级+八度+时值    (最严: 连节奏一起比)
"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import melody_oct as M

Q = "3565321232176"
TOK = re.compile(r"^([qsdh]*)([,']*)([0-9x])([.,\-]*)")
DUR = {"q": 0.5, "s": 0.25, "d": 0.125, "h": 0.0625, "": 1.0}


def beat(tok):
    m = TOK.match(tok)
    if not m:
        return None
    pre, acc, dig, post = m.groups()
    b = DUR.get(pre, 1.0)
    if "." in post:
        b *= 1.5
    b += post.count("-")
    return f"{dig}{acc.count(',')-acc.count(chr(39)):+d}:{b:g}"


def load(path):
    txt = io.open(path, encoding="utf-8", errors="replace").read()
    e, raws = M.enc(txt)
    a = "".join(x[0] for x in e)                    # A 音级
    b = "".join(e)                                  # B 音级+八度
    c = "".join(beat(t) or "" for t in raws)        # C +时值
    return a, b, c


def scan(root, tag):
    rows = []
    for f in sorted(glob.glob(os.path.join(root, "*.txt"))):
        try:
            a, b, c = load(f)
        except Exception:
            continue
        name = os.path.basename(f)[:-4]
        song = name.split("__")[0]
        if Q in b or Q in a:
            rows.append((song, name, a.count(Q), b.count(Q), c.count(
                "".join(f"{d}+0:{1:g}" for d in Q))))
    return rows


for tag, root in (("库内 scores", "jianpu-db-out/scores"),
                  ("batch-out", "batch-out")):
    print(f"\n===== {tag} =====")
    rows = scan(root, tag)
    A = [r for r in rows if r[2]]
    B = [r for r in rows if r[3]]
    print(f"  A 口径(丢八度) 命中: {len(A)} 首")
    for r in A:
        print(f"      {r[0][:44]:<46} ×{r[2]}" + ("   [B 也命中]" if r[3] else "   [B 不命中 -> 八度不同!]"))
    print(f"  B 口径(音级+八度, 检索器实际用的) 命中: {len(B)} 首")
    for r in B:
        print(f"      {r[0][:44]:<46} ×{r[3]}")

# 目标歌各自的实况
print("\n===== 目标歌实际片段 (B 口径逐位对照) =====")
qB = "".join(f"{d}+0" for d in Q)
for pat in ("jianpu-db-out/scores/爱上草原的小河*.txt", "batch-out/水手*.txt"):
    for f in sorted(glob.glob(pat)):
        a, b, c = load(f)
        i = b.find(qB)
        print(f"  {os.path.basename(f)[:44]:<46} B命中@{i if i>=0 else '-':>5}"
              f"   A命中@{a.find(Q) if a.find(Q)>=0 else '-'}   {b[max(0,i-8):i+len(qB)+8] if i>=0 else ''}")
