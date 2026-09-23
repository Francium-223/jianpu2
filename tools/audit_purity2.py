# -*- coding: utf-8 -*-
"""审计"纯度门回收"这一批新转的页: 有多少是纯垃圾, 与现有语料比质量。

用法: py -3.13 tools/audit_purity2.py
"""
import os
import re
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import batch_transcribe as BT

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0]")


def digits_of(tk):
    return sum(1 for t in tk if t.rstrip("'.") and t.rstrip("'.")[-1] in "1234567")


def row_of(f):
    tk = open(f, encoding="utf-8", errors="replace").read().split()
    notes = sum(1 for t in tk if NOTE.match(t))
    dig = digits_of(tk)
    x = sum(1 for t in tk if "x" in t)
    return len(tk), notes, dig, x


def report(label, files):
    n = len(files)
    if not n:
        print(f"{label}: 无文件")
        return
    tot_tok = tot_notes = tot_dig = tot_x = 0
    zero = low = 0
    note_list = []
    for f in files:
        try:
            nt, nn, nd, nx = row_of(f)
        except Exception:
            continue
        tot_tok += nt
        tot_notes += nn
        tot_dig += nd
        tot_x += nx
        note_list.append(nd)
        if nd == 0:
            zero += 1
        elif nd < 0.5 * max(nt, 1):
            low += 1
    note_list.sort()
    print(f"{label}  文件 {n}")
    print(f"  数字中位 {note_list[len(note_list)//2]}   合计数字 {tot_dig}   合计 token {tot_tok}")
    print(f"  数字=0 的页 {zero} ({100*zero/n:.0f}%)   数字占比<50% 的页 {low} ({100*low/n:.0f}%)")
    if tot_dig:
        print(f"  x 率(按数字) {100*tot_x/tot_dig:.2f}%")


def clean(new_files, junk_names):
    """把"垃圾页"(token>=20 且数字=0) 从 batch-out 移回 batch-out-bad (隔离, 不删)。

    为什么要清: `NOTE` 正则把 `x` 也算音符, 所以 finalize 的"空谱"过滤**抓不到**
    "380 个 x" 这种页, 它会作为一首 0 数字的曲子进语料。"""
    moved = 0
    for nm in junk_names:
        for ext in (".txt", ".png"):
            src = os.path.join("batch-out", nm + ext)
            if os.path.exists(src):
                dst = os.path.join("batch-out-bad", nm + ext)
                try:
                    if os.path.exists(dst):
                        os.remove(dst)
                    os.replace(src, dst)
                    if ext == ".txt":
                        moved += 1
                except Exception as ex:
                    print(f"  移动失败 {src}: {ex}")
    print(f"已移回隔离区 {moved} 个垃圾页 (txt+png)")


def main():
    names = [l.strip() for l in open("train-work/purity2_admit.txt", encoding="utf-8") if l.strip()]
    new_files = []
    for d in names:
        f = f"batch-out/{BT.safe_name(d)}.txt"
        if os.path.exists(f):
            new_files.append(f)
    print(f"放行名单 {len(names)}  已转出 {len(new_files)}\n")

    # 基线: 抽 300 个"本来就在语料里"的页(排除回收批)
    newset = {os.path.basename(f) for f in new_files}
    old = [f for f in sorted(
        __import__("glob").glob("batch-out/*.txt"))
        if os.path.basename(f) not in newset
        and not os.path.basename(f).startswith("hot_")]
    step = max(1, len(old) // 300)
    report("【基线】原有语料(抽 300):", old[::step][:300])
    print()
    report("【回收批】新转出的页:", new_files)

    # 列出纯垃圾页, 供人工/回滚判断
    junk = []
    for f in new_files:
        try:
            nt, nn, nd, nx = row_of(f)
        except Exception:
            continue
        if nd == 0 and nt >= 20:
            junk.append((nt, os.path.basename(f)[:-4]))
    junk.sort(reverse=True)
    print(f"\n纯垃圾页(数字=0 且 token>=20): {len(junk)} 个")
    for nt, nm in junk[:25]:
        print(f"  {nt:4d} token  {nm[:64]}")

    if "--clean" in sys.argv:
        clean(new_files, [nm for _nt, nm in junk])


if __name__ == "__main__":
    main()
