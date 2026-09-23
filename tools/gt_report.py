# -*- coding: utf-8 -*-
"""手写 GT 评测(配对透明版) —— 修掉 eval_all_gt.py 的假数字。

老脚本的两个坑:
  ① 只在 batch-out 里找 -> finalize 把结果移去 -dup/-bad/-empty/-suspect 后就"语料里没有" ✗;
  ② 同名多版本时**取最大文件** -> 拿到的是另一份谱(实测《小星星》配到 319 音的版本,
     而 GT 是 286 音的那份), 于是算出 1.6% 这种假数字 ✗。
这里: 五个结果目录一起找, 候选全列出来(**按音符数就近配对**), 并同时给两种口径:
  * 序列口径(SequenceMatcher, 只看结构对齐) —— 会被一个多读的 0 整段带偏
  * **音高袋口径**(对错位/漏多不敏感, 只比 "数字+低八度点数" 的多重集合) —— 更能代表"读对多少音"
用法: py -3.13 tools/gt_report.py [GT目录=train-work/gt_base]
"""
import glob
import os
import sys

sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from eval_gt import load_gt, load_out, score, score_bag

GTDIR = sys.argv[1] if len(sys.argv) > 1 else "train-work/gt_base"
RESULT_DIRS = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]


def candidates(kw):
    out = []
    for rd in RESULT_DIRS:
        for f in glob.glob(f"{rd}/*.txt"):
            if kw.lower() in os.path.basename(f).lower():
                try:
                    out.append((len(load_out(f)), rd, f))
                except Exception:
                    continue
    return sorted(out, key=lambda t: t[0])


rows = []
print(f"GT 目录 {GTDIR}\n")
for p in sorted(glob.glob(f"{GTDIR}/*.txt")):
    gt = os.path.basename(p)[:-4]
    kw = gt.split("__")[0]
    try:
        ng = len(load_gt(p))
    except Exception as e:
        print(f"{gt}: GT 读失败 {type(e).__name__}")
        continue
    cands = candidates(kw)
    print(f"=== {gt}   GT {ng} 音   候选 {len(cands)} 份")
    for n, rd, f in cands[:6]:
        print(f"      候选 {n:>5} 音  {rd:<20} {os.path.basename(f)[:52]}")
    if not cands:
        print("      没有任何转写 -> 跳过\n")
        continue
    # 就近配对: 音符数与 GT 最接近的那份
    n, rd, f = min(cands, key=lambda t: abs(t[0] - ng))
    ok, o, g = score(p, f)
    bag, g2 = score_bag(p, f)
    flag = "✓" if abs(o - ng) <= max(6, 0.1 * ng) else "⚠音符数差得多, 配对可疑"
    print(f"      -> 选中 {n} 音 ({rd})  序列 {ok}/{g} = {100*ok/max(g,1):.1f}%   "
          f"音高袋 {bag}/{g2} = {100*bag/max(g2,1):.1f}%   {flag}\n")
    rows.append((gt, o, g, ok, bag, abs(o - ng) <= max(6, 0.1 * ng)))

if rows:
    O = sum(r[1] for r in rows)
    G = sum(r[2] for r in rows)
    S = sum(r[3] for r in rows)
    B = sum(r[4] for r in rows)
    good = [r for r in rows if r[5]]
    print("=" * 78)
    print(f"全部 {len(rows)} 首: 输出 {O} 音 vs GT {G} 音   序列口径 {100*S/max(G,1):.1f}%   "
          f"音高袋口径 {100*B/max(G,1):.1f}%")
    if good:
        O2 = sum(r[1] for r in good)
        G2 = sum(r[2] for r in good)
        S2 = sum(r[3] for r in good)
        B2 = sum(r[4] for r in good)
        print(f"配对可信的 {len(good)} 首: 输出 {O2} 音 vs GT {G2} 音   序列口径 {100*S2/max(G2,1):.1f}%   "
              f"音高袋口径 {100*B2/max(G2,1):.1f}%")
    print("\n口径说明: 序列口径对插入/删除极敏感(开头多一个 `0` 会让后面整段判错), "
          "音高袋口径只比数字与低八度点数、对错位不敏感。")
    print("样本很小(手写 GT), 宣传时**必须**连样本量一起说。")
