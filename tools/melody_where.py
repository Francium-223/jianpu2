# -*- coding: utf-8 -*-
"""看一个乐句在各曲子里落在哪个 subtitle 段里(往前找最近的 subtitle=)。"""
import re, sys, os
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

PAT = re.compile(r"q,6\s+q3\s+q2\s+q3\s+q1\s+q3\s+q,7\s+q3")
for name in ("th02_01", "th04_18", "th11_08", "th04_19", "th17_14"):
    p = rf"D:\Documents_D\jianpu-db\scores\{name}.txt"
    if not os.path.exists(p):
        continue
    txt = open(p, encoding="utf-8", errors="replace").read()
    hits = list(PAT.finditer(txt))
    subs = [(m.start(), m.group(1)) for m in re.finditer(r"subtitle=(\S+)", txt)]
    print(f"=== {name}: 命中 {len(hits)} 次 ===")
    for m in hits[:8]:
        near = [s for s in subs if s[0] < m.start()]
        lab = near[-1][1] if near else "(文件开头之前)"
        # 往前找最近的 { 或 R n { 标记
        head = txt[max(0, m.start() - 40):m.start()].replace("\n", " ")
        print(f"   段={lab:12s} 前文…{head}")
    if not hits:
        print("   (无)")
