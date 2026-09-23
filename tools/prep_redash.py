# -*- coding: utf-8 -*-
"""定向重跑的准备工作: 按名单把受影响谱的旧 txt/png 备份并清掉。

为什么要清: transcribe_source.py 见到 batch-out/<name>.txt 已存在就跳过,
所以要让它们重转, 必须先移走旧结果。移走前先备份(可回退)。

用法: py -3.13 tools/prep_redash.py [名单文件]
"""
import os
import shutil
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import batch_transcribe as BT

LIST = sys.argv[1] if len(sys.argv) > 1 else "train-work/dash_affected.txt"
BK = "train-work/redash-backup"
os.makedirs(BK, exist_ok=True)

if not os.path.exists(LIST):
    print(f"名单不存在: {LIST}")
    sys.exit(1)

names = [l.strip() for l in open(LIST, encoding="utf-8") if l.strip()]
moved = missing = 0
for d in names:
    sn = BT.safe_name(d)
    for ext in (".txt", ".png"):
        src = f"batch-out/{sn}{ext}"
        if not os.path.exists(src):
            continue
        dst = os.path.join(BK, os.path.basename(src))
        try:
            if os.path.exists(dst):
                os.remove(dst)
            shutil.move(src, dst)
            if ext == ".txt":
                moved += 1
        except Exception as ex:
            print(f"  移动失败 {src}: {ex}")
    if not os.path.exists(os.path.join(BK, sn + ".txt")):
        missing += 1

print(f"名单 {len(names)} 个; 已备份并移走 {moved} 个旧转写 -> {BK}  (无可移 {missing})")
print("接下来 transcribe_source 会把它们重转一遍(新默认 JP_DASHMINW=8)")
