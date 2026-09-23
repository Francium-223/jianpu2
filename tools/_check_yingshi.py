# -*- coding: utf-8 -*-
"""试影视/经典名曲: 谁的谱里含 33332123223216（A+B 连续）或 223216 结尾。"""
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
NAMES = ["滚滚长江东逝水", "三国演义", "临江仙", "历史的天空", "这一拜", "有为歌",
         "好汉歌", "枉凝眉", "葬花吟", "红豆曲", "敢问路在何方", "女儿情", "天竺少女",
         "五百年桑田沧海", "通天大道", "向天再借五百年", "得民心者得天下", "雍正王朝",
         "大宅门", "乔家大院", "汉武大帝", "贞观长歌", "康熙王朝", "我爱我家",
         "上海滩", "万水千山总是情", "铁血丹心", "世间始终你好", "一生有意义"]


def load(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in "0x"]
    return "".join(x[0] for x, _ in pr), " ".join(r for _, r in pr[:24])


for nm in NAMES:
    fs = []
    for pat in ("jianpu-db-out/scores/*.txt", "batch-out/*.txt", "batch-out-dup/*.txt"):
        fs += [f for f in glob.glob(pat) if nm in os.path.basename(f)]
    if not fs:
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
    if bst:
        mn, at, b, raw = bst
        star = "★" if mn == 0 else ("~" if mn <= 2 else " ")
        print(f" {star} {nm:<16} 错{mn:<2} @{at+1 if at>=0 else '-':<4} {raw[:30]}")
