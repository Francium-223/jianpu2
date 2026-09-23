# -*- coding: utf-8 -*-
"""删掉"被挑页宽 > JP_MAXW"的谱的 txt, 便于增量重跑(尺寸阈值失效的那批)。"""
import glob, json, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

MW = int(os.environ.get("JP_MAXW", "2000"))
ranked = sorted(glob.glob("rank-out/ranked*.jsonl"))
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
    d = os.path.dirname(r["img"])
    if d in seen:
        continue
    seen.add(d)
    dirs.append(d)
dirs = dirs[:1531]

n = 0
wide = []
for d in dirs:
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        w, h = Image.open(p).size
    except Exception:
        continue
    if w <= MW:
        continue
    name = BT.safe_name(os.path.basename(d.rstrip("/\\")))
    txt = f"batch-out/{name}.txt"
    if os.path.exists(txt):
        os.remove(txt)
        for e in (".png",):
            if os.path.exists(f"batch-out/{name}{e}"):
                os.remove(f"batch-out/{name}{e}")
        n += 1
    wide.append((name, w, h))
print(f"宽度>{MW} 的谱 {len(wide)} 个, 已删除旧结果 {n} 个 (待重跑)")
for nm, w, h in wide[:6]:
    print(f"   {w}x{h}  {nm[:44]}")
