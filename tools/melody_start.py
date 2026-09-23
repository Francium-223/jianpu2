# -*- coding: utf-8 -*-
"""找出'以某段旋律开头'的曲子(按音高, 忽略休止/认不出的音)。
用在"这是什么歌"的听歌识曲: 人报的句子多半是开头。
用法: py tools/melody_start.py 1117637 1176755
"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

PATS = sys.argv[1:]
SOURCES = [
    ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("我转写的", "batch-out/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
]
SKIP = "0x"
for p in PATS:
    print(f"### 以 {p} 开头的曲子")
    total = 0
    for label, pat in SOURCES:
        hits = []
        for f in glob.glob(pat):
            b = os.path.basename(f)
            if b in ("progress.txt", "skipped.txt"):
                continue
            try:
                txt = open(f, encoding="utf-8", errors="replace").read()
            except Exception:
                continue
            e, raws = M.enc(txt)
            d = "".join(x[0] for x in e if x[0] not in SKIP)
            if d.startswith(p):
                tail = " ".join(raws[:16])
                hits.append((len(d), b[:-4], tail))
        hits.sort()
        if hits:
            print(f"  --- {label}: {len(hits)} ---")
            for n, name, tail in hits[:8]:
                print(f"      {name[:44]:46s} 共{n}音  开头: {tail}")
            total += len(hits)
    if total == 0:
        print("   (没有)")
    print()
