# -*- coding: utf-8 -*-
"""算"还没有任何已转写谱、也还没有待转写图"的金曲 -> 下一轮定向扫描的输入。

与 cover_forecast 的区别: 那个只看 batch-out(已转写); 这个还要看 images-prep 里"抓到图但还没转写"
的目录(mp034..mp094 还在转), 避免为已经抓到图的歌重复去爬。
输出: train-work/mandopop_still_missing.txt (歌名<TAB>歌手)
"""
import glob
import io
import os
import re
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！?？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
BR = re.compile(r"[（(\s　【\[《/].*$")


def norm(s):
    return DROP.sub("", re.sub(r"\[[^\]]*\]", "", s).translate(ZW)).casefold()


# 已转写
have = set()
for f in glob.glob("batch-out/*.txt") + glob.glob("batch-out-dup/*.txt"):
    b = os.path.basename(f)[:-4].split("__")[0]
    have.add(norm(b))
    have.add(norm(BR.sub("", b) or b))

# 已抓到图但可能还没转写
imgs = set()
for pat in ("images-prep/qupu123-mp*", "images-prep/qupu123-title*",
            "images-prep/jianpucn-title*", "images-prep/jianpujia-art*"):
    for d in glob.glob(pat):
        for sub in glob.glob(os.path.join(d, "*")):
            if os.path.isdir(sub):
                nm = os.path.basename(sub).split("__")[0]
                imgs.add(norm(nm))
                imgs.add(norm(BR.sub("", nm) or nm))

rows, still, covered_img = [], [], []
for line in io.open("train-work/mandopop_list.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    p = line.split("\t")
    t, a = p[0].strip(), (p[1].strip() if len(p) > 1 else "")
    q = norm(t)
    if not q:
        continue
    if q in have or any(q in k for k in have):
        continue
    if q in imgs or any(q in k for k in imgs):
        covered_img.append(t)
        continue
    still.append((t, a))

print(f"金曲清单 312 首")
print(f"  已转写: {312 - len(still) - len(covered_img)}")
print(f"  已抓到图待转写: {len(covered_img)}  -> " + " / ".join(covered_img))
print(f"  **完全没有谱: {len(still)}**")
with io.open("train-work/mandopop_still_missing.txt", "w", encoding="utf-8") as f:
    for t, a in still:
        f.write(f"{t}\t{a}\n")
print("  -> train-work/mandopop_still_missing.txt")
print("  " + " / ".join(t for t, _ in still))
