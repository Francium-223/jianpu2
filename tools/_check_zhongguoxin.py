# -*- coding: utf-8 -*-
"""核查:《我的中国心》在库里的转写是什么样; 用户的片段能不能对上(含八度变体)。"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

Q = "671375617"
DIG = "1234567"


def info(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    s = "".join(x[0] for x in e if x[0] not in "0x")
    enc = "".join(x for x in e if x[0] not in "0x")
    n = sum(1 for c in s if c in DIG)
    return s, enc, n, raws


print("=== 《我的中国心》相关文件 ===")
files = sorted(set(glob.glob("batch-out/我的中国心*.txt") + glob.glob("batch-out-dup/我的中国心*.txt")
                   + glob.glob("jianpu-db-out/scores/我的中国心*.txt")))
for f in files:
    s, enc, n, raws = info(f)
    print(f"  {f[-58:]:<60} 音符 {n:>4}  开头 {s[:34]}")

print("\n=== 用户片段的八度变体, 在库里谁能严格命中 ===")
variants = {
    "全中音区      6 7 1 3 7 5 6 1 7": "6 7 1 3 7 5 6 1 7",
    "1,3 高八度    6 7 '1 '3 7 5 6 1 7": "6 7 '1 '3 7 5 6 1 7",
    "1 高八度      6 7 '1 3 7 5 6 1 7": "6 7 '1 3 7 5 6 1 7",
    "1,3,6,1,7 高  6 7 '1 '3 7 5 '6 '1 '7": "6 7 '1 '3 7 5 '6 '1 '7",
    "6,7 低八度    ,6 ,7 1 3 7 5 6 1 7": ",6 ,7 1 3 7 5 6 1 7",
}
TOK = re.compile(r"^([qsdh]*)([,']*)([0-9x])")


def enc_of(s):
    out = []
    for t in s.split():
        m = TOK.match(t)
        if m:
            pre, acc, dig = m.groups()
            out.append(f"{dig}{acc.count(',')-acc.count(chr(39)):+d}")
    return "".join(out)


corp = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        try:
            s, enc, n, _ = info(f)
        except Exception:
            continue
        if n >= len(Q):
            corp[os.path.basename(f)[:-4]] = (s, enc)

for label, q in variants.items():
    qe = enc_of(q)
    qd = "".join(x[0] for x in [qe[i:i + 2] for i in range(0, len(qe), 2)])
    hitE = [k for k, (s, e) in corp.items() if qe in e]
    hitD = [k for k, (s, e) in corp.items() if q in s]
    print(f"  {label:<34} 严格(含八度) {len(hitE):>2} 首  丢八度 {len(hitD):>2} 首"
          + (f"   {[h[:26] for h in hitE[:3]]}" if hitE else ""))
