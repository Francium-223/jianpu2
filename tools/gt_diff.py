# -*- coding: utf-8 -*-
"""把 GT 与转写的对齐差异"摊开看": 是真错音, 还是插入/删除引起的**级联错位**。

GT 评测用 SequenceMatcher 在 (digit, low, 声部数) 上对齐, 所以**一个多余的 token
会让后面整段错位** —— 那种情况下"匹配率低"并不代表错了很多音。
本工具按 opcode 打印差异块, 并统计"级联长度"(一个 delete/insert 之后跟着多长的 replace)。

用法: py -3.13 tools/gt_diff.py [曲名, 默认 兄弟抱一下]
"""
import os
import sys
from difflib import SequenceMatcher

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from eval_gt import key, load_gt, load_out

NAME = sys.argv[1] if len(sys.argv) > 1 else "兄弟抱一下"
gt = f"train-work/gt/{NAME}.txt"
out = f"train-work/gt_eval/{NAME}.txt"
if not (os.path.exists(gt) and os.path.exists(out)):
    print(f"缺文件: {gt} 或 {out}")
    sys.exit(0)

OUT = load_out(out)
GT = load_gt(gt)
jo = [key(x) for x in OUT]
jg = [key(x) for x in GT]
sm = SequenceMatcher(None, [(k[0], k[1], k[2]) for k in jo], [(k[0], k[1], k[2]) for k in jg])

print(f"{NAME}:  输出 {len(OUT)} token   GT {len(GT)} token")
print(f"{'类型':<9}{'输出区间':>12}{'GT区间':>12}   内容")
print("-" * 96)
cascade = 0
n_cascade = 0
for tag, i1, i2, j1, j2 in sm.get_opcodes():
    if tag == "equal":
        continue
    o = " ".join(OUT[i1:i2])[:34]
    g = " ".join(GT[j1:j2])[:34]
    span = max(i2 - i1, j2 - j1)
    print(f"{tag:<9}{f'{i1}-{i2}':>12}{f'{j1}-{j2}':>12}   出[{o}]  GT[{g}]")
    if tag == "replace" and span >= 6:
        cascade += span
        n_cascade += 1
print("-" * 96)
print(f"大块 replace(>=6): {n_cascade} 块, 共 {cascade} token  "
      f"({'像是级联错位 ✗' if cascade > 0.4 * len(GT) else '分散错音 ✓'})")

# ---- 对"错位"不敏感的度量: 音高袋(bag of notes) ----
# 序列对齐(SequenceMatcher)会被一处插入/删除**整段带偏**, 于是"匹配率"远低于真实准确率 ✗。
# 音高袋只比 (数字, 八度) 的多重集合, 不管顺序和错位 ✓ —— 更能反映"到底读错了几个音"。
from collections import Counter

co = Counter((k[0], k[1]) for k in jo)
cg = Counter((k[0], k[1]) for k in jg)
common = sum((co & cg).values())
print()
print(f"音高袋(bag) 重合 {common} / GT {len(jg)} = {100*common/max(len(jg),1):.1f}%")
print(f"  只在输出里(多读): {sum((co-cg).values())}   只在 GT 里(漏读): {sum((cg-co).values())}")
print("  漏读最多的 (数字,低八度) 前 6:", (cg - co).most_common(6))
print("  多读最多的 (数字,低八度) 前 6:", (co - cg).most_common(6))
