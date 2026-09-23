# -*- coding: utf-8 -*-
"""量化八度错误: 把"数字相同、只有八度标记不同"的对齐位置单独数出来。

用的是已保存的 GT 与转写(不需要 GPU)。
  GT      : train-work/gt/<曲名>.txt
  转写    : train-work/gt_eval/<曲名>.txt
对齐用 difflib, 然后把差异分成:
  * 纯八度错(数字一样, 只差 / 或 ,)   <- 本次关注
  * 数字错(音高不对)
  统计低八度/高八度各自的方向, 看是不是单向偏(例如总把 5 读成 ,5)
"""
import glob
import io
import os
import re
import sys
from collections import Counter
from difflib import SequenceMatcher

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TOK = re.compile(r"^([,']*)([qsdhc]*)([,']*)([#b]*)([1-7x0])(.*)$")


def parse_tok(t):
    m = TOK.match(t)
    if not m:
        return None
    pre, dur, mid, acc, dig, post = m.groups()
    low = (pre + mid).count(",")
    voice = (pre + mid).count("'")
    return dict(low=low, voice=voice, digit=dig)


def load_gt(p):
    txt = io.open(p, encoding="utf-8", errors="replace").read()
    from eval_gt import load_gt
    return load_gt(p)


def load_out(p):
    from eval_gt import load_out
    return load_out(p)


total_oct = total_dig = 0
dirs = Counter()
bydigit = Counter()
per_song = []
for g in sorted(glob.glob("train-work/gt/*.txt")):
    name = os.path.basename(g)[:-4]
    o = f"train-work/gt_eval/{name}.txt"
    if not os.path.exists(o):
        continue
    GT, OUT = load_gt(g), load_out(o)
    a = [parse_tok(t) for t in GT]
    b = [parse_tok(t) for t in OUT]
    if not a or not b:
        continue
    oct_e = dig_e = 0
    sm = SequenceMatcher(None, GT, OUT, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            continue
        ga, ob = a[i1:i2], b[j1:j2]
        if len(ga) == len(ob):
            for x, y in zip(ga, ob):
                if x and y and x["digit"] == y["digit"] and x["digit"] not in ("-", "x"):
                    if (x["low"], x["voice"]) != (y["low"], y["voice"]):
                        oct_e += 1
                        if y["low"] > x["low"]:
                            dirs["GT正常 -> 转写加了低八度点"] += 1
                        elif y["low"] < x["low"]:
                            dirs["GT有低八度点 -> 转写丢了"] += 1
                        if y["voice"] > x["voice"]:
                            dirs["GT正常 -> 转写加了高八度点"] += 1
                        elif y["voice"] < x["voice"]:
                            dirs["GT有高八度点 -> 转写丢了"] += 1
                        bydigit[f"{x['digit']}"] += 1
                    else:
                        dig_e += 1
    total_oct += oct_e
    total_dig += dig_e
    per_song.append((name, oct_e, dig_e))

print("=== 每首 ===")
for name, o, d in per_song:
    print(f"  {name[:22]:<24} 纯八度错 {o:3d}   数字错 {d:3d}")
print(f"\n合计: 纯八度错 {total_oct}, 数字错 {total_dig}")
print("\n=== 八度错的方向 ===")
for k, v in dirs.most_common():
    print(f"  {v:4d}  {k}")
print("\n=== 哪些数字容易错八度 ===")
for k, v in bydigit.most_common():
    print(f"  {k}: {v}")
