# -*- coding: utf-8 -*-
"""查几个含"夜曲"的目录的转写状态。"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

def fix(s):
    try:
        d = s.encode("latin-1").decode("utf-8")
        if d and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in d):
            return d
    except Exception:
        pass
    return s

dirs = [p for p in glob.glob("images-prep/*/*") if "夜曲" in fix(os.path.basename(p))]
for d in dirs:
    raw = os.path.basename(d)
    nm = BT.safe_name(raw)
    txt = f"batch-out/{nm}.txt"
    if os.path.exists(txt):
        t = open(txt, encoding="utf-8").read().split()
        d2 = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        st = f"已转: {len(t)} token (数字{d2})"
    else:
        st = "无结果(未转或空)"
    p = BT.pick_page(d)
    sz = ""
    if p:
        try:
            w, h = Image.open(p).size
            sz = f"{os.path.basename(p)} {w}x{h}"
        except Exception:
            sz = os.path.basename(p) + " 读不出"
    print(f"{fix(raw)[:44]:46s} {st:22s} 页={sz}")
