# -*- coding: utf-8 -*-
"""把 jianpu-db/scores/*.txt 的 MBID= 迁移成 ID= + id-type=mbid。
原文件备份到 scores_bak_mbid/。已是 ID= 的跳过; 空的 MBID= 迁移成 ID= (留空待补)。
用法: py -3.13 tools/migrate_db_scores.py
"""
import glob, os, shutil, sys
sys.stdout.reconfigure(encoding="utf-8")

D = "D:/Documents_D/jianpu-db"
SRC = os.path.join(D, "scores")
BAK = os.path.join(D, "scores_bak_mbid")
os.makedirs(BAK, exist_ok=True)

files = sorted(glob.glob(os.path.join(SRC, "*.txt")))
print(f"scores/ 共 {len(files)} 个文件")
n_changed = n_id = n_empty = 0
for f in files:
    lines = open(f, encoding="utf-8").read().splitlines(keepends=True)
    out, changed, has_id = [], False, False
    for l in lines:
        s = l.replace(" ", "").lower()
        if s.startswith("mbid="):
            val = l.split("=", 1)[1].strip()
            out.append(f"ID={val}\n")
            if val:
                out.append("id-type=mbid\n")
            else:
                n_empty += 1
            changed = True
        elif s.startswith("id="):
            has_id = True
            out.append(l)
        else:
            out.append(l)
    if changed:
        shutil.copy2(f, os.path.join(BAK, os.path.basename(f)))
        with open(f, "w", encoding="utf-8") as g:
            g.write("".join(out))
        n_changed += 1
    elif has_id:
        n_id += 1

print(f"已迁移(MBID->ID): {n_changed} 个   已是 ID=: {n_id} 个   其中空 MBID {n_empty} 个")
print(f"备份目录: {BAK}")
