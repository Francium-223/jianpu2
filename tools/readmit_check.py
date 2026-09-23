# -*- coding: utf-8 -*-
"""找"被旧判据误杀"的金曲谱: batch-out-bad 里, 标题命中金曲清单、且**按现行判据应放行**的谱。

用途: 误杀直接压覆盖率。老判据是"nline>=5 就判非纯"(会被标题黑框/长连音线骗), 现行判据是
"nline>=5 **且** staff>=4, 或 staff>=5"。实测《铁血丹心》nline=7/staff=1 -> 现行应放行。
输出: train-work/readmit_list.txt (可直接交给"移回 batch-out"的步骤)
"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import kind_detect2 as K
import jp_transcribe as JP
import batch_transcribe as BT

ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")


def norm(s):
    return DROP.sub("", re.sub(r"\[[^\]]*\]", "", s).translate(ZW)).casefold()


want = [l.split("\t")[0].strip() for l in io.open("train-work/mandopop_list.txt", encoding="utf-8")
        if l.strip() and not l.startswith("#")]
wn = {w: norm(w) for w in want}

# 只查与本目标有关的: 标题命中金曲清单
cand = []
for f in glob.glob("batch-out-bad/*.txt"):
    b = os.path.basename(f)[:-4]
    bn = norm(b)
    for w, n in wn.items():
        if n and n in bn:
            cand.append((w, b))
            break
print(f"金曲清单里被拦在 batch-out-bad 的谱: {len(cand)} 份"
      f"(涉及 {len({w for w, _ in cand})} 首)\n")

pass_now, keep_bad, noimg = [], [], []
for w, b in cand:
    # txt -> 找图片: images-prep/*/<谱目录名>/
    img = None
    for d in glob.glob("images-prep/*/" + glob.escape(b)):
        for ext in ("*.jpg", "*.jpeg", "*.png", "*.gif"):
            g = [x for x in glob.glob(os.path.join(d, ext))
                 if "__pg" not in os.path.basename(x) or True]
            g = [x for x in g if os.path.getsize(x) > 20000]
            if g:
                img = max(g, key=os.path.getsize)
                break
        if img:
            break
    if not img:
        noimg.append((w, b))
        continue
    try:
        nl, wide, W, H, st = K.measure(img)
        imp = JP.impure_from(nl, st)
    except Exception as e:
        noimg.append((w, b))
        continue
    (keep_bad if imp else pass_now).append((w, b, nl, st))

print(f"按现行判据应放行: {len(pass_now)} 份")
for w, b, nl, st in pass_now[:30]:
    print(f"   {w:<14} nline={nl:>4} staff={st:>3}   {b[:52]}")
print(f"\n仍应拦: {len(keep_bad)} 份   找不到图: {len(noimg)} 份")

with io.open("train-work/readmit_list.txt", "w", encoding="utf-8") as f:
    for w, b, nl, st in pass_now:
        f.write(f"{b}\n")
print(f"\n写出 train-work/readmit_list.txt ({len(pass_now)} 行)")
