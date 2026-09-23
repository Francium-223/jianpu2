# -*- coding: utf-8 -*-
"""批量转写成果统计。"""
import glob, os, statistics, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

fs = glob.glob("batch-out/*.txt")
pngs = glob.glob("batch-out/*.png")
ns, dbl, xc = [], 0, 0
for f in fs:
    tk = open(f, encoding="utf-8").read().split()
    ns.append(len(tk))
    dbl += sum(1 for x in tk if "''" in x)
    xc += sum(1 for x in tk if "x" in x)
ok = [n for n in ns if n > 0]
print(f"转写结果: {len(fs)} 张 txt   标注图: {len(pngs)} 张")
print(f"  有效(>0音): {len(ok)}")
print(f"  平均 {statistics.mean(ok):.0f} 音   中位 {statistics.median(ok):.0f}")
print(f"  总音符: {sum(ns):,}")
print(f"  空(0音): {len(ns) - len(ok)}")
print(f"  双高八度残留: {dbl}")
print(f"  x(念白) token: {xc}")
skip = "batch-out/skipped.txt"
if os.path.exists(skip):
    print(f"  跳过(超长图): {len(open(skip, encoding='utf-8').read().splitlines())}")
err = "batch-out/errors.log"
if os.path.exists(err):
    import re
    t = open(err, "rb").read().decode("utf-8", "ignore")
    print(f"  错误: {len(re.findall(r'Traceback', t))} 个")
