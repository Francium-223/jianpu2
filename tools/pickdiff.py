# -*- coding: utf-8 -*-
"""算出 pick_page 新旧结果不同的谱, 删掉它们的 txt/png, 便于增量重跑。"""
import glob, json, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

def old_pick(d):
    cands = [f for f in glob.glob(os.path.join(d, "*.jpg")) if "__pg" not in os.path.basename(f)]
    if not cands:
        return None
    real = []
    for f in cands:
        try:
            w, h = Image.open(f).size
        except Exception:
            continue
        if h > 100 and w > 100:
            real.append(f)
    if not real:
        return None
    if "qupu123" in d:
        n2 = [f for f in real if os.path.basename(f).lower() == "002.jpg"]
        if n2:
            return n2[0]
    return max(real, key=os.path.getsize)

# 复现 batch 的目录顺序
ranked = sorted(glob.glob("rank-out/ranked*.jsonl"))
if ranked:
    rows = []
    for rf in ranked:
        for l in open(rf, encoding="utf-8"):
            try:
                rows.append(json.loads(l))
            except Exception:
                pass
    rows.sort(key=lambda r: r.get("play", 0), reverse=True)
    seen, dirs = set(), []
    for r in rows:
        dd = os.path.dirname(r["img"])
        if dd in seen:
            continue
        seen.add(dd)
        dirs.append(dd)
else:
    dirs = sorted(glob.glob("images-prep/*/*/"))

diff = []
for d in dirs:
    o = old_pick(d)
    n = BT.pick_page(d)
    if (o is None) != (n is None) or (o and n and os.path.basename(o) != os.path.basename(n)):
        diff.append((d, o, n))

print(f"pick_page 变化: {len(diff)} / {len(dirs)} 个目录")
n_del = 0
for d, o, n in diff:
    m = re.search(r"([A-Za-z]+\d*-\d+)$", d.rstrip("/\\"))
    key = m.group(1) if m else None
    # 用磁盘上的真实目录名(batch 的 txt 名 = 该目录名), 避开 jsonl 与磁盘的 mojibake 差异
    real = glob.glob(f"images-prep/*/*{glob.escape(key)}") if key else []
    if not real:
        print(f"  [无目录] {key}")
        continue
    name = os.path.basename(real[0].rstrip("/\\"))
    txt = os.path.join("batch-out", name + ".txt")
    if os.path.exists(txt):
        os.remove(txt); n_del += 1
        for p in [os.path.join("batch-out", name + ".png")]:
            if os.path.exists(p):
                os.remove(p)
        print(f"  {key:22s} {os.path.basename(o) if o else None} -> {os.path.basename(n) if n else None}")
    else:
        print(f"  [无txt] {key:22s} {os.path.basename(o) if o else None} -> {os.path.basename(n) if n else None}")
print(f"已删除 {n_del} 个旧 txt (待重跑)")
