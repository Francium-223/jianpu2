# -*- coding: utf-8 -*-
"""算当前批次的剩余量: next_batch.txt 里还有多少没转, 给出 ETA。"""
import glob, os, re, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

names = [l.strip() for l in open("train-work/next_batch.txt", encoding="utf-8") if l.strip()]
have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}
done = miss = 0
missing = []
for n in names:
    if BT.safe_name(n) in have:
        done += 1
    else:
        miss += 1
        missing.append(n)
print(f"批次名单 {len(names)}: 已完成 {done}, 剩余 {miss}")

# 用最近 30 个结果的写入时间估速度
fs = sorted(glob.glob("batch-out/*.txt"), key=os.path.getmtime)[-30:]
if len(fs) >= 2:
    span = os.path.getmtime(fs[-1]) - os.path.getmtime(fs[0])
    rate = span / max(len(fs) - 1, 1)
    print(f"最近 {len(fs)} 个平均 {rate:.1f} 秒/个 -> 剩余约 {miss*rate/3600:.1f} 小时")
    print(f"预计完成: {time.strftime('%H:%M', time.localtime(time.time() + miss*rate))}")
if missing[:5]:
    print("剩余样例:")
    for m in missing[:5]:
        print("   ", m[:52])
