# -*- coding: utf-8 -*-
"""全库搜索关键词(修 mojibake 后匹配)。用法: py tools/find_title.py 关键词"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def fix(s):
    try:
        d = s.encode("latin-1").decode("utf-8")
        if d and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in d):
            return d
    except Exception:
        pass
    return s

kw = sys.argv[1]
dirs = [os.path.basename(p) for p in glob.glob("images-prep/*/*")]
hits = [(d, fix(d)) for d in dirs if kw in fix(d)]
print(f"images-prep 目录中含「{kw}」: {len(hits)}")
for raw, d in hits:
    tid = []
    for p in glob.glob("images-prep/*/" + glob.escape(raw)):
        tid = p
    has = glob.glob("batch-out/*" + (raw[-1] and "") + "*.txt")
    print("   ", d[:64])

scores = [os.path.basename(f)[:-4] for f in glob.glob("jianpu-db-out/scores/*.txt")]
sh = [t for t in scores if kw in t]
print(f"scores 中含「{kw}」: {len(sh)}")
for t in sh:
    print("   ", t[:64])
