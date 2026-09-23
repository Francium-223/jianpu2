# -*- coding: utf-8 -*-
"""把"被自己的落选记录误搬"的择优胜出版从 batch-out-dup 搬回 batch-out。

背景(2026-09-22 实测): pick_best 的输入 kind2.tsv 对**多页谱**是每页一行, 同一目录会有 2-3 行
-> 同一目录既进 kept 又进 dropped -> finalize 第 4 步照着 drop_dup.txt 把**胜出者**也搬进
batch-out-dup。名单见 train-work/lost_winners.txt(pick_best.tsv 的选中 dir 里, 当前不在
batch-out 而在 batch-out-dup 的那些), 实测 260 首。

可逆: 只搬不删, 每一步都记进 train-work/restore_lost.log, 后悔了按日志反着搬即可。
用法: py -3.13 tools/restore_lost_winners.py [--dry]
"""
import io
import os
import shutil
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DRY = "--dry" in sys.argv

lost = [l.strip() for l in io.open("train-work/lost_winners.txt", encoding="utf-8") if l.strip()]
print(f"待搬回 {len(lost)} 个胜出目录 (dry={DRY})")

log = io.open("train-work/restore_lost.log", "a", encoding="utf-8")
n_txt = n_img = 0
for d in lost:
    moved = []
    for ext in (".txt", ".png", ".jpg", ".jpeg"):
        src = os.path.join("batch-out-dup", d + ext)
        if not os.path.exists(src):
            continue
        dst = os.path.join("batch-out", d + ext)
        if os.path.exists(dst):
            continue
        if not DRY:
            shutil.move(src, dst)
        moved.append(os.path.basename(src))
        if ext == ".txt":
            n_txt += 1
        else:
            n_img += 1
    if moved:
        log.write(f"{d}\t{','.join(moved)}\n")
        log.flush()
print(f"搬回 txt {n_txt} 个, 附带图 {n_img} 个")
log.close()

# 复核: 这些目录现在在 batch-out 里了吗
have = {os.path.basename(f)[:-4] for f in __import__("glob").glob("batch-out/*.txt")}
still = [d for d in lost if d not in have]
print(f"复核: 仍在 batch-out 之外的 {len(still)} 个" + (f" 例: {still[:3]}" if still else ""))
