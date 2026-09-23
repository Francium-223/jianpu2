# -*- coding: utf-8 -*-
"""检查"同名取最优版本"的实际效果: 对若干知名歌, 列出选中的版本与落选数,
并给出选中版本的转写音符数(太少的说明选错了)。
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

sel = {r["dir"]: r for r in csv.DictReader(open("train-work/pick_best.tsv", encoding="utf-8"), delimiter="\t")}

def notes_of(d):
    nm = BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        g = glob.glob("batch-out/*" + d[-10:] + ".txt")
        f = g[0] if g else None
    if not f or not os.path.exists(f):
        return None
    t = open(f, encoding="utf-8").read().split()
    return sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")

WANT = ["富士山下", "十年", "K歌之王", "童话", "童年", "好久不见", "断点", "女儿情", "上海滩",
        "月亮代表我的心", "小星星", "卖报歌", "春天在哪里", "两只老虎", "勇气", "可惜不是你"]
print(f"{'歌':<16}{'选中版本':<40}{'他版':>5}{'音符':>6}")
print("-" * 72)
for w in WANT:
    hits = [r for r in sel.values() if w.lower() in r["dir"].lower()]
    if not hits:
        print(f"{w:<16}{'(语料里没有)':<40}")
        continue
    hits.sort(key=lambda r: -int(r["others"]))
    r = hits[0]
    n = notes_of(r["dir"])
    print(f"{w:<16}{r['dir'][:38]:<40}{r['others']:>5}{n if n is not None else '未转':>6}")
