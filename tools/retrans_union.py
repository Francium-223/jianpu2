# -*- coding: utf-8 -*-
"""合并两份受影响名单, 删除对应旧结果, 供增量补转。"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

names = set()
for f in ("train-work/boundfix_sheets.txt", "train-work/href_sheets.txt"):
    if os.path.exists(f):
        for l in open(f, encoding="utf-8"):
            if l.strip():
                names.add(l.strip())
names = sorted(names)
print(f"合并名单: {len(names)} 个")

n_del = 0
for raw in names:
    nm = BT.safe_name(raw)
    hit = glob.glob(f"batch-out/{glob.escape(nm)}.txt")
    if not hit:
        m = re.search(r"([A-Za-z]+\d*-\d+)$", raw)
        if m:
            hit = glob.glob(f"batch-out/*{glob.escape(m.group(1))}.txt")
    for h in hit:
        os.remove(h); n_del += 1
        png = h[:-4] + ".png"
        if os.path.exists(png):
            os.remove(png)
print(f"已删除旧结果 {n_del} 个 -> 跑 batch 增量补转")
with open("train-work/retrans_all.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(names))
