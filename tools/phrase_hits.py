# -*- coding: utf-8 -*-
"""在指定曲谱文件里查若干音高串(忽略八度/休止)的位置。
用法: py tools/phrase_hits.py <txt...> -- <短语...>
"""
import os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

argv = sys.argv[1:]
cut = argv.index("--") if "--" in argv else len(argv)
files = argv[:cut]
phrases = argv[cut + 1:]

for f in files:
    try:
        t = open(f, encoding="utf-8", errors="replace").read()
    except Exception as e:
        print(f"{f}: 读不到 ({e})")
        continue
    e, raws = M.enc(t)
    d = "".join(x[0] for x in e if x[0] not in "0x")
    print(f"--- {f}   {len(d)} 音")
    for q in phrases:
        i = d.find(q)
        print(f"    {q:10s} " + (f"位置 {i}" if i >= 0 else "没有"))
    i = d.find(phrases[0]) if phrases else -1
    if i >= 0:
        lo = max(0, i - 4)
        print(f"    第一段所在原文: {' '.join(raws[lo:i + len(phrases[0]) + 14])}")
    print()
