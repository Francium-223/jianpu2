# -*- coding: utf-8 -*-
"""安全网: 把"念白 x 占比异常高"的转写结果移出语料到 batch-out-suspect/。

理由: 全库 x 占比 3.4%, 而 x>=30% 的谱实测全是误转 —— 吉他编配/钢琴伴奏/五线谱
漏过纯度门后, 大量音被读成念白记号(如《阿猫阿狗》536 token 里 272 个 x)。
这类谱即使纯度门没抓住, 也不该进语料。
注意: 只"移出"不删, 便于人工复核。
用法: py tools/quarantine_highx.py [--dry]
"""
import glob, os, shutil, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

DRY = "--dry" in sys.argv
MIN_TOK = 20        # 太短的谱不判(样本不足)
XR = 0.30           # x 占比阈值
NMIN = 10           # x 绝对数下限

os.makedirs("batch-out-suspect", exist_ok=True)
moved = 0
notes = 0
for f in glob.glob("batch-out/*.txt"):
    b = os.path.basename(f)
    if b in ("progress.txt", "skipped.txt"):
        continue
    toks = open(f, encoding="utf-8").read().split()
    if len(toks) < MIN_TOK:
        continue
    nx = sum(1 for x in toks if "x" in x)
    if nx >= NMIN and nx / len(toks) >= XR:
        notes += sum(1 for x in toks
                     if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        moved += 1
        if not DRY:
            shutil.move(f, os.path.join("batch-out-suspect", b))
            png = f[:-4] + ".png"
            if os.path.exists(png):
                shutil.move(png, os.path.join("batch-out-suspect", os.path.basename(png)))
print(f"{'[dry] ' if DRY else ''}高 x 率移出 {moved} 个 (带走音符 {notes})")
