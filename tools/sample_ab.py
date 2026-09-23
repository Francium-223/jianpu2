# -*- coding: utf-8 -*-
"""A/B: 同一批谱在不同行带过滤模式下(JP_ROWFILTER)的 token 统计。
用法: py -3.13 tools/sample_ab.py <模式> [样本清单文件]
"""
import glob, json, os, re, sys, time
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

mode = sys.argv[1] if len(sys.argv) > 1 else "frac_abs"
os.environ["JP_ROWFILTER"] = mode
lst = sys.argv[2] if len(sys.argv) > 2 else "train-work/ab_sample.txt"
imgs = [l.strip() for l in open(lst, encoding="utf-8") if l.strip()]

import jp_transcribe as JP

tot = dict(n=0, dig=0, q=0, x=0, dash=0, rest=0, other=0)
rows = []
for img in imgs:
    name = os.path.basename(os.path.dirname(img))
    t0 = time.time()
    try:
        toks, meta = JP.render(img, "train-work/ab_tmp.png")
    except Exception as ex:
        print(f"  {name[:40]}: 失败 {type(ex).__name__} {ex}")
        continue
    c = dict(n=len(toks), dig=0, q=0, x=0, dash=0, rest=0, other=0)
    for t in toks:
        core = t.lstrip("qsdh,").rstrip("'.")
        if core == "?":            c["q"] += 1
        elif core == "x":          c["x"] += 1
        elif core == "-":          c["dash"] += 1
        elif core == "0":          c["rest"] += 1
        elif core and core[-1].isdigit() and core[-1] != "0": c["dig"] += 1
        else:                      c["other"] += 1
    for k in tot: tot[k] += c[k]
    rows.append((c["n"], c["dig"], c["q"], c["x"], name))
    print(f"  {name[:44]:46s} 音{c['n']:4d} 数字{c['dig']:4d} ?{c['q']:3d} x{c['x']:3d} "
          f"杠{c['dash']:3d} 休{c['rest']:3d} ({time.time()-t0:.0f}s)", flush=True)

print(f"\n=== 模式 {mode} | {len(rows)} 谱 ===")
print(f"token {tot['n']}  数字 {tot['dig']}  ? {tot['q']}  x {tot['x']}  "
      f"杠 {tot['dash']}  休止 {tot['rest']}  其他 {tot['other']}")
