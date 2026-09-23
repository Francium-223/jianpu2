# -*- coding: utf-8 -*-
"""合并待转名单: (a) 尚未转写的新爬目录 + (b) 宽度[700,950) 需重转的谱。
输出 train-work/next_batch.txt
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
# 已被隔离的(非纯简谱 / 落选重复版本)不该重转
quar = {os.path.basename(f)[:-4] for f in glob.glob("batch-out-bad/*.txt")}
quar |= {os.path.basename(f)[:-4] for f in glob.glob("batch-out-dup/*.txt")}
print(f"隔离区合计 {len(quar)} 个(跳过)")
a, b = [], []
for d in sorted(x for x in glob.glob("images-prep/*/*") if os.path.isdir(x)):
    name = os.path.basename(d.rstrip("/\\"))
    nm = BT.safe_name(name)
    if nm not in have:
        if nm in quar:
            continue
        # 只看新源(其它源没结果的多半是被隔离/落选的, 不该重转)
        if "jianpucn-pop" in d:
            a.append(name)
        continue
    p = BT.pick_page(d)
    if not p:
        continue
    try:
        w, h = Image.open(p).size
    except Exception:
        continue
    if 700 <= w < 950:
        b.append(name)
print(f"未转的新源目录 {len(a)} 个; 需重转的 [700,950) 谱 {len(b)} 个")
# (b) 的结果可能已被上一轮删除 -> 与早先存下的 mid_need.txt 合并
midf = "train-work/mid_need.txt"
if os.path.exists(midf):
    mid = [l.strip() for l in open(midf, encoding="utf-8") if l.strip()]
    extra = [m for m in mid if m not in b]
    print(f"  另从 mid_need.txt 补回 {len(extra)} 个")
    b += extra
allb = a + b
with open("train-work/next_batch.txt", "w", encoding="utf-8") as g:
    g.write("\n".join(allb))
print(f"合计 {len(allb)} -> train-work/next_batch.txt")
