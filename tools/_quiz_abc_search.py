# -*- coding: utf-8 -*-
"""在 ABC 转来的 jianpu-ly 库里搜 366563 / 377673 —— 华语库之外的第二旋律库。"""
import glob
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = r"D:\Documents_D\abc2jianpu\out-abcn"
FRAGS = ["366563", "377673", "66563", "77673", "3665", "3776"]

files = glob.glob(os.path.join(ROOT, "**", "*.jly"), recursive=True)
print(f"ABC 库文件 {len(files)} 个")
if not files:
    sys.exit("找不到 .jly（检查路径）")

TOK = re.compile(r"([,']*)([0-9])")


def digits(txt):
    out = []
    for line in txt.splitlines():
        s = line.strip()
        if not s or s.startswith("%") or re.match(r"^[A-Za-z_]+\s*=", s):
            continue
        for m in TOK.finditer(s):
            if m.group(2) in "01234567":
                out.append(m.group(2))
    return "".join(x for x in out if x in "1234567")


hits = {f: [] for f in FRAGS}
for f in files:
    try:
        s = digits(io.open(f, encoding="utf-8", errors="replace").read())
    except Exception:
        continue
    for fr in FRAGS:
        if fr in s:
            hits[fr].append((os.path.basename(f)[:-4], s.find(fr) + 1))

for fr in FRAGS:
    print(f"\n=== {fr}: 命中 {len(hits[fr])} 首 ===")
    for b, i in hits[fr][:25]:
        print(f"   @{i:<5} {b[:58]}")
