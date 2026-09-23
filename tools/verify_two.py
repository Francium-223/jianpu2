# -*- coding: utf-8 -*-
"""核实《甜蜜蜜》匹配 + 复查《夜曲》, 并导出两首原谱。"""
import glob, io, os, re, sys
sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
from PIL import Image
import batch_transcribe as BT

NOTE = re.compile(r"^[,']*[qsdhc]*[,']*([1-7])")


def digs_of(f):
    d = io.open(f, encoding="utf-8").read().split()
    return "".join(NOTE.match(t).group(1) for t in d if NOTE.match(t))


for pat, q, label in [("*甜蜜蜜__jianpucn-34367*", "3563121253", "甜蜜蜜"),
                      ("*夜曲__jianpucn-35562*", "67111137766654515", "夜曲")]:
    for f in glob.glob("batch-out/" + pat):
        if not f.endswith(".txt"):
            continue
        d = digs_of(f)
        print(f"{label}: {len(d)} 音")
        print(f"  开头 46: {d[:46]}")
        print(f"  含查询 {q}: {q in d}  位置 {d.find(q)}")
        # 导出原谱
        sid = re.search(r"-(\d+)\.txt$", f)
        if sid:
            for dirp in glob.glob("images-prep/*/*" + sid.group(1)):
                p = BT.pick_page(dirp)
                if p:
                    im = Image.open(p).convert("RGB")
                    if im.width > 950:
                        im = im.resize((950, int(im.height * 950 / im.width)), Image.LANCZOS)
                    out = f"train-work/{label}_原谱.png"
                    im.save(out)
                    print(f"  原谱 -> {out} {im.size}  ({os.path.basename(dirp)[:40]})")
                break
        print()
