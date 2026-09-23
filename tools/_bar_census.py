# -*- coding: utf-8 -*-
"""量: 全库有多少曲谱真的写了小节线 `|`(排除 R{..} A{..} 里的变体分隔)。"""
import glob
import io
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
DB = r"D:\Documents_D\jianpu-db"
n = 0
withbar = []
for f in glob.glob(DB + r"\scores\*.txt"):
    if f.endswith("_expand.txt"):
        continue
    n += 1
    t = io.open(f, encoding="utf-8", errors="replace").read()
    body = t.split("%--", 1)[-1]
    # 去掉 R{..} 与 A{..} 内容后再数 |
    body2 = re.sub(r"R\d*\s*\{.*?\}(\s*A\s*\{.*?\})?", " ", body, flags=re.DOTALL)
    if "|" in body2:
        withbar.append(f.split("\\")[-1])
print(f"全库 {n} 份; 正文(排除 R/A 块)里含小节线 | 的: {len(withbar)} ({len(withbar)/n*100:.1f}%)")
for x in withbar[:12]:
    print("   ", x)
