# -*- coding: utf-8 -*-
"""检查 pick_page 修复效果: 对当前空谱, 看新/旧挑页差异; 并抽样多页目录统计。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

files = [f for f in glob.glob("batch-out/*.txt")
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
empty = [os.path.basename(f)[:-4] for f in files
         if len(open(f, encoding="utf-8").read().split()) < 3]
print(f"空谱 {len(empty)} 个\n")
changed = 0
for name in empty[:40]:
    hits = [p for p in glob.glob("images-prep/*/" + glob.escape(name)) if os.path.isdir(p)]
    if not hits:
        continue
    d = hits[0]
    cands = [f for f in glob.glob(os.path.join(d, "*.jpg")) if "__pg" not in os.path.basename(f)]
    info = []
    for f in cands:
        try:
            w, h = Image.open(f).size
        except Exception:
            continue
        info.append((f, w, h))
    if not info:
        continue
    old = max([t[0] for t in info if t[2] > 100 and t[1] > 100] or [t[0] for t in info],
              key=os.path.getsize)
    new = BT.pick_page(d)
    if new and os.path.basename(new) != os.path.basename(old):
        changed += 1
        ow = [t for t in info if t[0] == old]
        nw = [t for t in info if t[0] == new]
        print(f"  {name[:28]:30s} 旧={os.path.basename(old)} {ow[0][1]}x{ow[0][2]}"
              f"  ->  新={os.path.basename(new)} {nw[0][1]}x{nw[0][2]}")
print(f"\n前 40 个空谱里, pick_page 改变了 {changed} 个")
