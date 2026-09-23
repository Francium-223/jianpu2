# -*- coding: utf-8 -*-
"""样本: 用新 pick_page 挑页, 走 jp_transcribe 生产路径, 统计 数字/?/x。"""
import glob, os, sys, time
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
import batch_transcribe as BT

def stat(img):
    toks, meta = JP.render(img, "train-work/_s.png")
    q = x = d = 0
    for t in toks:
        c = t.lstrip("qsdh,").rstrip("'.")
        if c == "?": q += 1
        elif c == "x": x += 1
        elif c and c[-1] in "1234567": d += 1
    return len(toks), d, q, x

dirs = sorted(glob.glob("images-prep/*/*/"))
# 采样: 均匀取 40 个多页 + 40 个单页? 直接取前 80 个(qupu123 双谱为主)
sel = dirs[:40]
tot = dict(n=0, d=0, q=0, x=0, empty=0)
for d in sel:
    page = BT.pick_page(d)
    if not page:
        continue
    name = os.path.basename(d)
    try:
        n, dig, q, x = stat(page)
    except Exception as ex:
        print(f"  {name[:30]}: 失败 {type(ex).__name__}")
        continue
    tot["n"] += n; tot["d"] += dig; tot["q"] += q; tot["x"] += x
    if n == 0: tot["empty"] += 1
    print(f"  {name[:34]:36s} 音{n:4d} 数字{dig:4d} ?{q:3d} x{x:3d}", flush=True)
print(f"\n样本 {len(sel)}: token{tot['n']} 数字{tot['d']} ?{tot['q']} x{tot['x']} 空{tot['empty']}")
