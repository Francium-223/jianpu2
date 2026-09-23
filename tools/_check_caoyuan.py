# -*- coding: utf-8 -*-
"""查草原/蒙古风名曲里有没有 33332123223216 这个乐句, 并打印各自开头, 供认歌。"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

LINE = "33332123223216"
TAIL = "223216"
NAMES = ["鸿雁", "草原之夜", "蒙古人", "天堂", "敖包相会", "草原上升起不落的太阳",
         "美丽的草原我的家", "父亲的草原母亲的河", "呼伦贝尔大草原", "天边", "鸿雁飞",
         "久别的草原", "山茶花", "对花", "森吉德玛", "嘎达梅林", "牧歌", "草原晨曲",
         "草原恋", "我和草原有个约定", "陪你一起看草原", "月光下的凤尾竹"]


def load(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    return "".join(x[0] for x, _ in pr), " ".join(r for _, r in pr[:26])


for nm in NAMES:
    fs = []
    for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
        fs += [f for f in glob.glob(pat) if nm in os.path.basename(f)]
    if not fs:
        print(f"  {nm:<16} 库里没有")
        continue
    bst = None
    for f in fs:
        s, raw = load(f)
        mn = 99
        at = -1
        if len(s) >= len(LINE):
            for i in range(len(s) - len(LINE) + 1):
                m = sum(1 for x, y in zip(s[i:i + len(LINE)], LINE) if x != y)
                if m < mn:
                    mn, at = m, i
        if bst is None or mn < bst[0]:
            bst = (mn, at, os.path.basename(f)[:-4], raw)
    mn, at, b, raw = bst
    flag = "★逐音一致" if mn == 0 else (f"最小错{mn}")
    print(f"  {nm:<16} {flag:<8} @{at+1 if at>=0 else '-':<4} 开头: {raw[:30]}")
