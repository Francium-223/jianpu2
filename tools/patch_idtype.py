# -*- coding: utf-8 -*-
"""补 id-type 行: 对已有 ID= 但缺 id-type= 的 jianpu-db 曲谱, 按 ID 值推断类型并插入。"""
import glob, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
SRC = "D:/Documents_D/jianpu-db/scores"
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
QID = re.compile(r"^Q\d+$")

n = 0
for f in sorted(glob.glob(os.path.join(SRC, "*.txt"))):
    lines = open(f, encoding="utf-8").read().splitlines(keepends=True)
    if any(l.replace(" ", "").lower().startswith("id-type=") for l in lines):
        continue
    out, done = [], False
    for l in lines:
        out.append(l)
        s = l.replace(" ", "").lower()
        if not done and s.startswith("id="):
            val = l.split("=", 1)[1].strip()
            t = "mbid" if UUID.match(val) else ("wikidata" if QID.match(val) else ("custom" if val else ""))
            if t:
                out.append(f"id-type={t}\n")
            done = True
    if done:
        open(f, "w", encoding="utf-8").write("".join(out))
        n += 1
print(f"补 id-type 的文件: {n}")
