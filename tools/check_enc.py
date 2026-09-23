# -*- coding: utf-8 -*-
"""验证: 文件名编码 + jianpu-db 的高八度写法。"""
import os, glob, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

print("=== batch-out 文件名(前5) ===")
for f in sorted(glob.glob("batch-out/*.txt"))[:5]:
    print("  ", os.path.basename(f))

print("=== 转换后 title(前5) ===")
for f in sorted(glob.glob("jianpu-db-out/scores/*.txt"))[:5]:
    for line in open(f, encoding="utf-8"):
        if line.startswith("title="):
            print("  ", line.strip()); break

print("=== jianpu-db 高八度写法 ===")
t = open("D:/Documents_D/jianpu-db/scores/th01_01.txt", encoding="utf-8").read()
print("  数字+撇(后置):", re.findall(r"[0-9x]'+", t)[:10])
print("  撇+数字(前置):", re.findall(r"'[0-9x]", t)[:5])
print("=== 我们的 token 高八度写法 ===")
ours = open(sorted(glob.glob("batch-out/*.txt"))[10], encoding="utf-8").read()
print("  含撇 token:", [x for x in ours.split() if "'" in x][:10])
