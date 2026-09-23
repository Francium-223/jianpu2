# -*- coding: utf-8 -*-
"""验证管线里的纯简谱门: 各已知样本的 nline + 是否会被挡。"""
import glob, sys
sys.path.insert(0, "tools"); sys.path.insert(0, "tools")
import os
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
from PIL import Image

CASES = [
    ("images-prep/test-jianpujia/春天在哪里简谱_儿歌_快来儿歌里找春天__jianpujia-15770/001.jpg", "spring 锚点"),
    ("train-work/check_10year.png", "十年(小而纯)"),
]
for t in ["K歌之王__jianpucn-40413", "爱情转移(富士山下)__jianpucn-118124",
          "去看拉萨河__qupu123-395689", "夜空中最亮的星（五线谱）__qupu123-333873"]:
    g = glob.glob("images-prep/*/" + glob.escape(t))
    if g:
        jp = glob.glob(g[0] + "/*.jpg") + glob.glob(g[0] + "/*.png")
        if jp:
            CASES.append((jp[0], t[:30]))

for p, name in CASES:
    if not os.path.exists(p):
        print(f"  {name[:34]:36s} 缺文件")
        continue
    try:
        nl, wd = JP._nline_big(p)
        w, h = Image.open(p).size
    except Exception as e:
        print(f"  {'读不出图':>10}  {name[:34]:36s} {type(e).__name__}")
        continue
    bad = nl >= 5 or wd >= 45
    print(f"  nline={nl:4d} wide={wd:4d}  {'挡掉(非纯)' if bad else '通过(纯简谱)'}   {name[:34]:36s} {w}x{h}")
