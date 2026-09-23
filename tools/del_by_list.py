# -*- coding: utf-8 -*-
"""按目录名名单删除 batch-out 里的旧结果(供增量重转)。用法: py tools/del_by_list.py <名单文件> [src前缀]"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

lst = sys.argv[1]
names = [l.split("\t")[0].strip() for l in open(lst, encoding="utf-8") if l.strip()]
n = 0
for raw in names:
    nm = BT.safe_name(raw)
    for f in glob.glob(f"batch-out/{glob.escape(nm)}.txt"):
        os.remove(f); n += 1
        png = f[:-4] + ".png"
        if os.path.exists(png):
            os.remove(png)
print(f"删除 {n} 个旧结果 (名单 {len(names)})")
