# -*- coding: utf-8 -*-
"""用 train-work/gt/ 的全部 GT 批量评测当前语料(复用 eval_gt.py 的既有口径)。
按标题在 batch-out 里找对应的转写结果。用法: py tools/eval_all_gt.py
"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import score

# GT 名 -> 在 batch-out 文件名里找的关键字
PAIRS = [
    ("春天在哪里", "春天在哪里"),
    ("小星星", "小星星"),
    ("外婆的澎湖湾", "澎湖湾"),
    ("时间都去哪了", "时间都去哪了"),
    ("兄弟抱一下", "兄弟抱一下"),
    ("快乐父子俩", "快乐父子俩"),
    ("排排坐", "排排坐"),
    ("Lemon_用户", "Lemon"),
]

def find_txt(kw):
    best = None
    for f in glob.glob("batch-out/*.txt"):
        if kw.lower() in os.path.basename(f).lower():
            try:
                n = len(open(f, encoding="utf-8").read().split())
            except Exception:
                continue
            if best is None or n > best[1]:
                best = (f, n)
    return best

print(f"{'曲目':<14}{'输出':>6}{'GT':>6}{'OK':>6}{'匹配率':>9}   文件")
print("-" * 76)
rows = []
for gt, kw in PAIRS:
    p = f"train-work/gt/{gt}.txt"
    if not os.path.exists(p):
        continue
    hit = find_txt(kw)
    if not hit:
        print(f"{gt:<14}{'-':>6}{'-':>6}{'-':>6}{'-':>9}   (语料里没有)")
        continue
    f = hit[0]
    try:
        ok, o, g = score(p, f)
    except Exception as e:
        print(f"{gt:<14} 评测失败 {type(e).__name__}")
        continue
    rows.append((gt, o, g, ok))
    print(f"{gt:<14}{o:>6}{g:>6}{ok:>6}{100*ok/max(g,1):>8.1f}%   {os.path.basename(f)[:32]}")
if rows:
    print("-" * 76)
    O = sum(r[1] for r in rows); G = sum(r[2] for r in rows); K = sum(r[3] for r in rows)
    print(f"{'合计':<14}{O:>6}{G:>6}{K:>6}{100*K/max(G,1):>8.1f}%   (宽松口径: 只比 数字/八度/声部)")
