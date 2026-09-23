# -*- coding: utf-8 -*-
"""按 README 的状态给 jianpu-db/scores/*.txt 加显式标记。

README 约定: ⬛=无文件;  🟥=有旋律但"待整理";  其它 emoji(☯️/🐢/...)=已整理。
标记(与 jianpu-db 的三级 status 一致):
    status=midi  由 MIDI 硬转来的(README 里的 🟥), 不进 data.jsonl
    status=ok    人工校对过, 可直接用
(本项目自己用图片 OCR 产出的写 status=ocr)

用法: py -3.13 tools/mark_db_status.py
"""
import glob, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")

DB = "D:/Documents_D/jianpu-db"
README = os.path.join(DB, "README.md")
SRC = os.path.join(DB, "scores")

# 解析 README: 每首曲目的 emoji
status = {}
for l in open(README, encoding="utf-8").read().splitlines():
    if "scores/" not in l:
        continue
    # 注意: emoji 可能是"多码位"(如 ☯️ = U+262F + U+FE0F), 必须用 [^\]]+ 而非 .
    for emo, fname in re.findall(r"\[([^\]]+)\]\(scores/([^)]+)\)", l):
        if emo.strip() == "⬛":
            continue                      # 无文件
        status[fname] = "midi" if "🟥" in emo else "ok"

print(f"README 标记: midi(🟥) {sum(1 for v in status.values() if v=='midi')} 首, "
      f"ok(其它) {sum(1 for v in status.values() if v=='ok')} 首")

n_marked = 0
for f in sorted(glob.glob(os.path.join(SRC, "*.txt"))):
    base = os.path.basename(f)
    # expand 版继承原曲状态
    key = base
    if key not in status and base.endswith("_expand.txt"):
        key = base.replace("_expand.txt", ".txt")
    st = status.get(key)
    if not st:
        continue
    lines = open(f, encoding="utf-8").read().splitlines(keepends=True)
    if any(l.replace(" ", "").lower().startswith("status=") for l in lines):
        continue                          # 已有标记
    out, inserted = [], False
    for l in lines:
        out.append(l)
        if not inserted and l.replace(" ", "").startswith("%--"):
            out.insert(len(out) - 1, f"status={st}\n")     # 插在 %-- 之前
            inserted = True
    if not inserted:                      # 没有 %-- 就插在最后一个元数据行后
        out.append(f"status={st}\n")
    with open(f, "w", encoding="utf-8") as g:
        g.write("".join(out))
    n_marked += 1

print(f"已标记文件: {n_marked}")
