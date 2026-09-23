# -*- coding: utf-8 -*-
"""决定性实验: 同一段旋律, 带/不带末两音的低八度记号, 分别命中谁。"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

TOK = re.compile(r"^([qsdh]*)([,']*)([0-9x])")


def enc_of(s):
    out = []
    for t in s.split():
        m = TOK.match(t)
        if m:
            pre, acc, dig = m.groups()
            out.append(f"{dig}{acc.count(',')-acc.count(chr(39)):+d}")
    return "".join(out)


def corpus(root):
    d = {}
    for f in glob.glob(os.path.join(root, "*.txt")):
        txt = io.open(f, encoding="utf-8", errors="replace").read()
        e, _ = M.enc(txt)
        nm = os.path.basename(f)[:-4]
        d[nm] = ("".join(e), "".join(x[0] for x in e))
    return d


S = corpus("jianpu-db-out/scores")
B = corpus("batch-out")

QUERIES = {
    "Q1 中音区(用户原样)  3 5 6 5 3 2 1 2 3 2 1 7 6":
        "3 5 6 5 3 2 1 2 3 2 1 7 6",
    "Q2 末两音低八度      3 5 6 5 3 2 1 2 3 2 1 ,7 ,6":
        "3 5 6 5 3 2 1 2 3 2 1 ,7 ,6",
}

for label, q in QUERIES.items():
    qB = enc_of(q)
    qA = "".join(x[0] for x in [qB[i:i + 2] for i in range(0, len(qB), 2)])
    print(f"\n===== {label}")
    print(f"     编码 {qB}")
    for tag, D in (("入库", S), ("batch-out", B)):
        hB = [n for n, (b, a) in D.items() if qB in b]
        hA = [n for n, (b, a) in D.items() if qA in a]
        print(f"  {tag:<10} 严格(含八度)命中 {len(hB):>2} 首: " +
              (" / ".join(n[:30] for n in sorted(hB)[:6]) or "无"))
        print(f"  {'':<10} 宽松(丢八度)命中 {len(hA):>2} 首: " +
              (" / ".join(n[:30] for n in sorted(hA)[:6]) or "无"))

# 全库: "1 ,7 ,6" 这个下行结尾有多普遍?
print("\n===== 常见度检查(库内, 严格口径)")
for frag, desc in (("3 5 6 5 3 2 1 2 3 2 1 ,7 ,6", "带低八度结尾"),
                   ("3 5 6 5 3 2 1 2 3 2 1 7 6", "中音区结尾"),
                   ("1 ,7 ,6", "低八度下行三音(短)"),
                   ("3 5 6 5 3", "开头五音")):
    qB = enc_of(frag)
    hB = [n for n, (b, a) in S.items() if qB in b] + \
         [n + "(待入库)" for n, (b, a) in B.items() if qB in b]
    print(f"  {desc:<16} {frag:<26} 命中 {len(hB):>3} 首  {[n[:24] for n in sorted(hB)[:5]]}")
