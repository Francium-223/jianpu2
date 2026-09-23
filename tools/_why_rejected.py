# -*- coding: utf-8 -*-
"""为什么《铁血丹心》这张纯简谱被纯度门拦了? 量它的 nline / staff, 并与已接受的谱对比。"""
import glob
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import kind_detect2 as K
import jp_transcribe as JP

BAD = int(os.environ.get("JP_BADLINE", "5"))
SMAX = int(os.environ.get("JP_STAFFMAX", "4"))
SHARD = int(os.environ.get("JP_STAFFHARD", "5"))
print(f"判据: nline>={BAD} 且 staff>={SMAX} -> 非纯;  另: staff>={SHARD} 一律非纯\n")

tests = [("被拦的《铁血丹心》纯简谱", "images-prep/qupu123-crawl/铁血丹心__qupu123-381085/002.jpg")]
# 对照组: 已进语料的简谱(同名旧抓 / 今日新抓)
for pat in ("images-prep/qupu123-mp*/水手__qupu123-268596/*",
            "images-prep/qupu123-mp*/上春山*/*", "images-prep/hot-crawl/上春山*/*"):
    g = [x for x in glob.glob(pat) if x.lower().endswith((".jpg", ".png", ".jpeg"))]
    if g:
        tests.append((f"对照(已接受) {os.path.basename(os.path.dirname(g[0]))[:28]}", g[0]))

for name, p in tests:
    if not os.path.exists(p):
        print(f"  {name[:34]:<36} 文件不存在")
        continue
    try:
        nl, wide, W, H, st = K.measure(p)
    except Exception as e:
        print(f"  {name[:34]:<36} 测量失败 {type(e).__name__}")
        continue
    imp = JP.impure_from(nl, st)
    print(f"  {name[:34]:<36} nline={nl:>4} staff={st:>3} wide={wide:>3}  {W}x{H}  "
          f"-> {'非纯(拦)' if imp else '纯(放行)'}")
