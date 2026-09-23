# -*- coding: utf-8 -*-
"""预检: 各"新抓目录"里的谱**按现行纯度判据**能不能过 —— 预测转写收益(避免把六线谱当战果)。"""
import glob
import os
import sys
from collections import Counter

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import kind_detect2 as K
import jp_transcribe as JP

PATTERNS = ["images-prep/qupu123-mp9*", "images-prep/qupu123-title*",
            "images-prep/jianpucn-title*", "images-prep/jianpujia-art*",
            "images-prep/jianpujia-cat*", "images-prep/qupu123-sweep*"]
for root in PATTERNS:
    dirs = []
    for d in glob.glob(root):
        dirs += [x for x in glob.glob(os.path.join(d, "*")) if os.path.isdir(x)]
    if not dirs:
        print(f"{root}: 0 个谱目录")
        continue
    verdict = Counter()
    imp = []
    for d in dirs:
        imgs = [x for x in glob.glob(os.path.join(d, "*"))
                if x.lower().endswith((".jpg", ".jpeg", ".png", ".gif"))
                and os.path.getsize(x) > 20000]
        if not imgs:
            verdict["无图"] += 1
            continue
        img = max(imgs, key=os.path.getsize)
        try:
            nl, wide, W, H, st = K.measure(img)
            bad = JP.impure_from(nl, st)
        except Exception:
            verdict["测量失败"] += 1
            continue
        if bad:
            verdict["非纯(拦)"] += 1
            imp.append((os.path.basename(d), nl, st))
        else:
            verdict["纯(放行)"] += 1
    tot = sum(verdict.values())
    ok = verdict.get("纯(放行)", 0)
    print(f"\n{root}: {tot} 个谱目录  ->  纯 {ok} ({ok/max(1,tot)*100:.0f}%)  "
          f"{dict(verdict)}")
    for b, nl, st in imp[:6]:
        print(f"      拦: nline={nl:>4} staff={st:>2}  {b[:52]}")
