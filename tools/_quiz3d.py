# -*- coding: utf-8 -*-
"""列全库所有含 366563 / 含 377673 的曲名(去重, 按位置排序), 供人工认歌。"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

SKIP = "0x"


def pitch(f):
    e, _ = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    return "".join(x[0] for x in e if x[0] not in SKIP)


def title(b):
    t = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", b.split("__")[0])
    return re.sub(r"\s+", " ", t).strip()


for frag in ("366563", "377673"):
    rows = []
    for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
        for f in glob.glob(pat):
            try:
                s = pitch(f)
            except Exception:
                continue
            i = s.find(frag)
            if i >= 0:
                rows.append((i, title(os.path.basename(f)[:-4])))
    # 同曲名去重(保留最早位置)
    best = {}
    for i, t in rows:
        if t not in best or i < best[t]:
            best[t] = i
    print(f"\n===== 含 {frag} 的曲目 {len(best)} 个 (按位置) =====")
    for t, i in sorted(best.items(), key=lambda x: x[1]):
        print(f"   @{i:<5} {t[:56]}")
