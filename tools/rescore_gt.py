# -*- coding: utf-8 -*-
"""用修好的解析器重新给已存的 GT 评测结果打分(纯 CPU, 不需要重新转写)。

背景: 原先 token_json 只认"前置时值"(q3), 不认 GT 常用的"后置"(3q),
导致 GT 的八分音符全被当成四分 -> 匹配率虚低到 31.5%。
"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import score

pairs = []
for img in sorted(glob.glob("train-work/gt/*.jpg")):
    base = img[:-4]
    out = f"train-work/gt_eval/{os.path.basename(base)}.txt"
    if os.path.exists(base + ".txt") and os.path.exists(out):
        pairs.append((os.path.basename(base), out, base + ".txt"))

print(f"{'曲目':<16}{'输出':>6}{'GT':>6}{'OK':>6}{'匹配率':>9}")
print("-" * 46)
rows = []
for name, out, gt in pairs:
    ok, o, g = score(gt, out)
    rows.append((name, o, g, ok))
    print(f"{name:<16}{o:>6}{g:>6}{ok:>6}{100*ok/max(g,1):>8.1f}%")
if rows:
    print("-" * 46)
    O = sum(r[1] for r in rows); G = sum(r[2] for r in rows); K = sum(r[3] for r in rows)
    print(f"{'合计':<16}{O:>6}{G:>6}{K:>6}{100*K/max(G,1):>8.1f}%")
    print("\n(口径: 只比 数字/八度/声部, 与 spring 锚点同口径)")
