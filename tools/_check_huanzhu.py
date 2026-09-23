# -*- coding: utf-8 -*-
"""核对: 还珠格格主题曲《当》(动力火车) 的开头 vs 库里的《失踪》; 两首是不是同一段旋律。
用户给的: 1123555 55 5532
"""
import glob
import io
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

Q = "1123555555532"
CAND = ["当", "雨蝶", "自从有了你", "你是风儿我是沙", "不能和你分手", "失踪", "还珠"]
SKIP = "0x"


def load(f):
    e, raws = M.enc(io.open(f, encoding="utf-8", errors="replace").read())
    pr = [(x, r) for x, r in zip(e, raws) if x[0] not in SKIP]
    return "".join(x[0] for x, _ in pr), " ".join(x for x, _ in pr[:20]), " ".join(r for _, r in pr[:20])


def best_mismatch(s, q):
    if len(s) < len(q):
        return None
    mn, at = 99, -1
    for i in range(len(s) - len(q) + 1):
        m = sum(1 for a, b in zip(s[i:i + len(q)], q) if a != b)
        if m < mn:
            mn, at = m, i
    return mn, at


for name in CAND:
    fs = sorted(set(glob.glob(f"batch-out/*{name}__*.txt") + glob.glob("batch-out-dup/*" + name + "__*.txt")))
    # 精确匹配 名为 name 的文件(避免 当 -> 担当)
    fs = [f for f in fs if os.path.basename(f).split("__")[0].strip() == name] or fs
    if not fs:
        print(f"\n=== {name}: 库里没有")
        continue
    for f in fs[:3]:
        s, enc, raw = load(f)
        r = best_mismatch(s, Q)
        print(f"\n=== {os.path.basename(f)[:-4][:54]}  音符 {len(s)}")
        print(f"    开头 20 音(简谱): {raw}")
        print(f"    开头 20 音(编码): {enc}")
        print(f"    与你的 13 音最小错配: {r[0] if r else '-'} @第{r[1]+1 if r else '-'}音"
              + (f"   谱里: {s[max(0,r[1]-2):r[1]+len(Q)+2]}" if r else ""))
