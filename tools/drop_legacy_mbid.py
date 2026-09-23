# -*- coding: utf-8 -*-
"""删除曲谱里 legacy 的小写 `mbid=` 行(保留大写的 MBID=)。

两者值实测完全相同(309/309), 属于冗余; 而 Linux 上大小写是区分的, 会导致
by_mbid/ 与 by_MBID/ 两个目录并存。
"""
import glob
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu-db")

fs = [f for f in glob.glob("scores/*.txt")
      if not f.endswith(("_expand.txt", "_buf.txt"))]
# 只匹配小写 mbid=(re 默认区分大小写, 不会碰 MBID=)。整行连同行尾一起删。
PAT = re.compile(r"(?m)^[ \t]*mbid[ \t]*=[^\r\n]*(?:\r\n|\n|$)")

changed = 0
rows = 0
for f in fs:
    s = io.open(f, encoding="utf-8", newline="").read()
    s2, n = PAT.subn("", s)
    if n:
        io.open(f, "w", encoding="utf-8", newline="").write(s2)
        changed += 1
        rows += n

print(f"处理 {len(fs)} 份, 改动 {changed} 份, 删除 {rows} 行")

# 复查
lo = up = 0
for f in fs:
    s = io.open(f, encoding="utf-8", newline="").read()
    if re.search(r"(?m)^[ \t]*mbid[ \t]*=", s):
        lo += 1
    if re.search(r"(?m)^[ \t]*MBID[ \t]*=", s):
        up += 1
print(f"复查: 仍含小写 mbid= {lo} 份, 含大写 MBID= {up} 份")
s = io.open(fs[0], encoding="utf-8", newline="").read()
print(f"\n样例 {os.path.basename(fs[0])} 的元数据:")
for l in s.splitlines()[:11]:
    print("   ", l)
