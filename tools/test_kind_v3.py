# -*- coding: utf-8 -*-
"""验证组合判据(nline OR wide)在已知样本上的表现。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from kind_detect2 import measure
import batch_transcribe as BT

CASES = [
    ("K歌之王__jianpucn-40413", "纯"),
    ("去看拉萨河__qupu123-395689", "纯(密集)"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯"),
    ("爱情转移(富士山下)__jianpucn-118124", "吉他"),
    ("第一次__jianpucn-87448", "吉他"),
    ("最佳损友__jianpucn-456171", "吉他"),
    ("一切还好__jianpucn-8758", "吉他"),
    ("淘汰__jianpucn-2971", "吉他"),
    ("老公老公我爱你__jianpucn-86799", "吉他"),
    ("夜空中最亮的星（五线谱）__qupu123-333873", "五线谱"),
]
ok = 0
for t, kind in CASES:
    g = glob.glob("images-prep/*/" + glob.escape(t))
    if not g:
        print(f"{t[:36]:38s} 找不到")
        continue
    p = BT.pick_page(g[0])
    try:
        nl, wd, w, h = measure(p)
    except Exception:
        print(f"{t[:36]:38s} 读不出图")
        continue
    pure = nl < 5 and wd < 45
    want_pure = kind.startswith("纯")
    good = pure == want_pure
    ok += good
    print(f"{'纯 ' if pure else '非纯'}  nline={nl:3d} wide={wd:3d}  {'✓' if good else '✗'}  期望[{kind:8s}] {t[:34]}")
print(f"\n{ok}/{len(CASES)} 正确")
