# -*- coding: utf-8 -*-
"""把`prune_offtarget`误判搬走的目录**搬回来**(用修好的归一化规则重新判定)。

事故: 曲名带 `&nbsp;` 实体时, 旧的 norm 把它变成 `绿光nbspnbsp`, 于是 `绿光` 被判成"误命中"搬走。
本脚本按 train-work/prune_offtarget.log 逐条重判: 规则通过就搬回 images-prep/<原目录>。
用法: py -3.13 tools/restore_offtarget.py [--dry]
"""
import io
import os
import re
import shutil
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

# 自带 norm(不 import prune_offtarget —— 那是个脚本, import 会把清理逻辑再跑一遍)
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")
PAREN = re.compile(r"[（(【\[][^)）】\]]*[)）】\]]|[（(【\[].*$")


def norm(s):
    s = ENT.sub("", s)
    s = re.sub(r"\[[^\]]*\]", "", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[0-9０-９]+$", "", s)
    return DROP.sub("", s.translate(ZW)).casefold()


DRY = "--dry" in sys.argv
log_path = "train-work/prune_offtarget.log"
if not os.path.exists(log_path):
    sys.exit("没有 train-work/prune_offtarget.log")

rows = []
for line in io.open(log_path, encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if len(c) >= 3:
        rows.append(c[:3])            # want, title, base
print(f"移出记录 {len(rows)} 条")

# 原始目录归属: 按 base 里的站点前缀推回 qupu123-title / jianpucn-title
back, stayed = [], []
for want, title, base in rows:
    wn, tn = norm(want), norm(title)
    ok = (wn == tn) or (len(wn) > 3 and wn in tn)
    if not ok:
        stayed.append(base)
        continue
    src = os.path.join("images-prep/_offtarget", base)
    if not os.path.isdir(src):
        continue
    dst_root = "images-prep/qupu123-title" if "qupu123" in base else "images-prep/jianpucn-title"
    dst = os.path.join(dst_root, base)
    if os.path.exists(dst):
        continue
    if not DRY:
        os.makedirs(dst_root, exist_ok=True)
        shutil.move(src, dst)
    back.append(base)

print(f"\n应搬回 {len(back)} 个 (dry={DRY}):")
for b in back:
    print("   " + b[:70])
print(f"\n仍留在 _offtarget(确属误命中) {len(stayed)} 个")
