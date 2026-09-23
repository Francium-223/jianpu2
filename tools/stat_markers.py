# -*- coding: utf-8 -*-
"""统计抽查: 新转写的谱里, 连音线(~)和圆滑线(括号)的出现率, 与 GT 对照判断是否过度检出。
GT 参考(兄弟抱一下, 211 音): 连音线 1 个(~0.5%), 圆滑线 4 个(2 对, ~1.9%)。
"""
import glob, io, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import load_gt

# GT 基准
gt = load_gt("train-work/gt/兄弟抱一下.txt")
raw = io.open("train-work/gt/兄弟抱一下.txt", encoding="utf-8").read().split()
gt_tie = raw.count("~")
gt_slur = sum(1 for t in raw if t == "(")
print(f"GT 基准(兄弟抱一下): {len(gt)} 音, 连音线 {gt_tie} 个({100*gt_tie/len(gt):.1f}%), "
      f"圆滑线 {gt_slur} 个({100*gt_slur/len(gt):.1f}%)")

files = [f for f in sorted(glob.glob("batch-out/*.txt"))
         if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
n = nt = ns = nd = 0
with_tie = with_slur = 0
for f in files:
    toks = io.open(f, encoding="utf-8").read().split()
    d = sum(1 for x in toks if re.match(r"^[,']*[qsdhc]*[,']*[1-7]", x))
    if not d:
        continue
    n += 1
    nt += toks.count("~")
    ns += sum(1 for x in toks if x == "(")
    nd += d
    if "~" in toks:
        with_tie += 1
    if "(" in toks:
        with_slur += 1
print(f"\n新语料 {n} 个谱, {nd} 音")
print(f"  连音线 {nt} 个 ({100*nt/max(nd,1):.1f}%), 出现在 {with_tie} 个谱里 ({100*with_tie/max(n,1):.0f}%)")
print(f"  圆滑线 {ns} 个 ({100*ns/max(nd,1):.1f}%), 出现在 {with_slur} 个谱里 ({100*with_slur/max(n,1):.0f}%)")
print(f"\n判读: 若远高于 GT 基准, 说明把时值线误当弧线了")
