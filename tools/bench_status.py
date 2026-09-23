# -*- coding: utf-8 -*-
"""只读: 看基准集 100 首现在有多少已有可用转写(不写任何文件)。"""
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

RD = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]
BAD = {"batch-out-bad", "batch-out-empty"}
done = {}
for rd in RD:
    for f in glob.glob(f"{rd}/*.txt"):
        done[os.path.basename(f)[:-4]] = rd

idx = {}
for d in glob.glob("images-prep/*/*"):
    if os.path.isdir(d):
        b = os.path.basename(d)
        # 去零宽字符, 否则 `\u200b算什么男人` 匹配不上基准集标题; 空键还要退回原名
        b2 = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", b)
        _head = re.split(r"[（(\s　【\[《]", b2.split("__")[0])[0] or b2.split("__")[0]
        idx.setdefault(_head, []).append(b)

songs = [l.strip() for l in open("train-work/bench_final100.txt", encoding="utf-8") if l.strip()]
ok, miss = [], []
for s in songs:
    ds = idx.get(s, [])
    if any(done.get(d) and done[d] not in BAD for d in ds):
        ok.append(s)
    else:
        miss.append(s)
print(f"基准集 {len(songs)} 首: 已有可用转写 {len(ok)}, 仍缺 {len(miss)}")
if miss:
    print("仍缺: " + "、".join(miss))
print(f"batch-out {len(glob.glob('batch-out/*.txt'))} / -dup {len(glob.glob('batch-out-dup/*.txt'))} / "
      f"-bad {len(glob.glob('batch-out-bad/*.txt'))} / -empty {len(glob.glob('batch-out-empty/*.txt'))} / "
      f"-suspect {len(glob.glob('batch-out-suspect/*.txt'))}")
