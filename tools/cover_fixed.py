# -*- coding: utf-8 -*-
"""用 title_match 的 canon 规则**重测覆盖率**(修正"宽松命中"的假阳性)。

对照能看到修正前后的差: canon 生效后, 中原担当/青花瓷/小夜曲/恶狼传说 这些不再算命中。
输出 train-work/mandopop_cover_fixed.tsv
"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import title_match as TM

SOURCES = {
    "① 已交付(jianpu-db-out/scores)": ["jianpu-db-out/scores/*.txt"],
    "② + batch-out(待入库)": ["jianpu-db-out/scores/*.txt", "batch-out/*.txt"],
    "③ + batch-out-dup(含将落选版本, 乐观)": ["jianpu-db-out/scores/*.txt", "batch-out/*.txt",
                                             "batch-out-dup/*.txt"],
}


def keys_of(pats):
    ks = set()
    for pat in pats:
        for f in glob.glob(pat):
            nm = os.path.basename(f)[:-4]
            ks.add(TM.head_of(nm))
            ks.add(nm.split("__")[0])
    return {k for k in ks if k.strip()}


LIST = []
for line in io.open("train-work/mandopop_list.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    p = line.split("\t")
    LIST.append((p[0].strip(), p[1].strip() if len(p) > 1 else ""))
n = len(LIST)

print(f"清单 {n} 首\n")
print(f"{'口径':<38}{'严格':>8}{'占比':>9}")
detail = {}
for lab, pats in SOURCES.items():
    KEYS = keys_of(pats)
    rows = []
    for t, a in LIST:
        verdict, who = "缺", ""
        for k in KEYS:
            v = TM.match(k, t)
            if v == "严格":
                verdict, who = "严格", k
                break
            if v == "宽松" and verdict == "缺":
                verdict, who = "宽松", k
        rows.append((t, a, verdict, who))
    ok = sum(1 for r in rows if r[2] == "严格")
    lo = sum(1 for r in rows if r[2] == "宽松")
    print(f"{lab:<38}{ok:>8}{ok/n*100:>8.1f}%   (+宽松 {lo})")
    detail[lab] = rows

rows = detail["① 已交付(jianpu-db-out/scores)"]
miss = [r[0] for r in rows if r[2] == "缺"]
print(f"\n【已交付口径】仍缺 {len(miss)} 首: " + " / ".join(miss))
loose = [(r[0], r[3]) for r in rows if r[2] == "宽松"]
print(f"\n【已交付口径】宽松命中 {len(loose)} 首(人工复核: 绝大多数是假阳性, 不计入覆盖):")
for t, w in loose:
    print(f"   {t:<14} <- {w[:40]}")
with io.open("train-work/mandopop_cover_fixed.tsv", "w", encoding="utf-8") as f:
    for t, a, v, w in detail["③ + batch-out-dup(含将落选版本, 乐观)"]:
        f.write(f"{t}\t{a}\t{v}\t{w}\n")
print("\n写出 train-work/mandopop_cover_fixed.tsv (口径③)")

