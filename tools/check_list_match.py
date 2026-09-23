# -*- coding: utf-8 -*-
"""校验名单匹配: 名单里的谱现在是否已在 batch-out 里(以及能否按 ID 找回)。"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

names = [l.strip() for l in open("train-work/boundfix_sheets.txt", encoding="utf-8") if l.strip()]
have = miss = 0
no_id = []
for raw in names:
    m = re.search(r"([A-Za-z]+\d*-\d+)$", raw)
    if not m:
        no_id.append(raw)
        continue
    if glob.glob(f"batch-out/*{glob.escape(m.group(1))}.txt"):
        have += 1
    else:
        miss += 1
print(f"名单 {len(names)}: 已在 batch-out {have}, 尚未 {miss}, 无ID {len(no_id)}")
for n in no_id[:5]:
    print("   无ID:", n[:60])
