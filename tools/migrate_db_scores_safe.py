# -*- coding: utf-8 -*-
"""安全迁移: jianpu-db/scores/*.txt 的 MBID= -> ID= + id-type=mbid。
只认合法 UUID; 值不合法就原样保留(绝不去动它)。
原文件备份到 scores_bak_mbid/。已是 ID= 的跳过。
用法: py -3.13 tools/migrate_db_scores_safe.py
"""
import glob, os, re, shutil, sys
sys.stdout.reconfigure(encoding="utf-8")

SRC = "D:/Documents_D/jianpu-db/scores"
BAK = "D:/Documents_D/jianpu-db/scores_bak_mbid"
UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
os.makedirs(BAK, exist_ok=True)

files = sorted(glob.glob(os.path.join(SRC, "*.txt")))
n_ok = n_skip = n_bad = 0
for f in files:
    lines = open(f, encoding="utf-8").read().splitlines(keepends=True)
    out, changed = [], False
    for l in lines:
        s = l.replace(" ", "").lower()
        if s.startswith("mbid=") and not s.startswith("mbid_type"):
            raw = l.split("=", 1)[1].strip()
            if UUID.match(raw):                      # 只迁移合法 UUID
                out.append("ID=" + raw + "\n")
                out.append("id-type=mbid\n")
                changed = True
                continue
            else:
                n_bad += 1
                print(f"  !! 非法 MBID, 保持原样: {os.path.basename(f)}  {raw[:44]!r}", flush=True)
        out.append(l)
    if changed:
        if not os.path.exists(os.path.join(BAK, os.path.basename(f))):
            shutil.copy2(f, os.path.join(BAK, os.path.basename(f)))
        with open(f, "w", encoding="utf-8") as g:
            g.write("".join(out))
        n_ok += 1
    else:
        n_skip += 1

print(f"\n迁移 {n_ok} 个   跳过 {n_skip} 个   非法(保持原样) {n_bad} 个")

# 自检: 所有 ID= 值必须合法(uuid 或 Q\d+ 或空)
bad = []
for f in sorted(glob.glob(os.path.join(SRC, "*.txt"))):
    for l in open(f, encoding="utf-8"):
        s = l.replace(" ", "").lower()
        if s.startswith("id=") and not s.startswith("id-type="):
            v = l.split("=", 1)[1].strip()
            if v and not UUID.match(v) and not re.match(r"^Q\d+$", v):
                bad.append((os.path.basename(f), v[:50]))
print(f"自检: 非法 ID 值 {len(bad)} 个")
for b in bad[:5]:
    print("  ", b)
