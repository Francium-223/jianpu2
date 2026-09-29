# -*- coding: utf-8 -*-
"""对比"多页回锅"前后的转录稿(只读): 旧稿在 batch-out-multipage-old/, 新稿在 batch-out/。

数出来的是**实测**改善量: token 数、音符数字个数、变长/变短/不变各多少、中位数倍数。
用法: py -3.13 _analysis/compare_multipage.py [--csv 输出.csv]
"""
import argparse
import os
import re
import statistics

ROOT = r"D:\Documents_D\jianpu2"
OLD = os.path.join(ROOT, "batch-out-multipage-old")
NEW = os.path.join(ROOT, "batch-out")


def nums(txt):
    """音符数字个数(去掉 % 头与 key=value 行)。"""
    body = []
    for line in txt.splitlines():
        if line.startswith("%") or re.match(r"^[A-Za-z_]+=", line):
            continue
        body.append(line)
    return len(re.findall(r"[0-9]", " ".join(body)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="")
    a = ap.parse_args()
    rows = []
    if not os.path.isdir(OLD):
        print(f"没有 {OLD} —— 还没做过回锅")
        return
    for f in sorted(os.listdir(OLD)):
        if not f.endswith(".txt"):
            continue
        p_new = os.path.join(NEW, f)
        if not os.path.exists(p_new):
            rows.append((f, nums(open(os.path.join(OLD, f), encoding="utf-8", errors="replace").read()), -1))
            continue
        o = nums(open(os.path.join(OLD, f), encoding="utf-8", errors="replace").read())
        n = nums(open(p_new, encoding="utf-8", errors="replace").read())
        rows.append((f, o, n))

    done = [r for r in rows if r[2] >= 0]
    more = [r for r in done if r[2] > r[1]]
    same = [r for r in done if r[2] == r[1]]
    less = [r for r in done if r[2] < r[1]]
    print(f"回锅目录 {len(rows)} 个: 新稿已出 {len(done)} · 变长 {len(more)} · 不变 {len(same)} · 变短 {len(less)}")
    if done:
        d = [r[2] - r[1] for r in more]
        print(f"变长的那批: 中位 +{statistics.median(d):.0f} 音, 最大 +{max(d)} 音, 合计 +{sum(d)} 音")
        print(f"变短的: 合计 {sum(r[2]-r[1] for r in less)} 音(要抽查是不是把和弦谱/五线谱页拼进来了)")
        print(f"新稿音符数中位数 {statistics.median([r[2] for r in done]):.0f}  vs 旧稿 {statistics.median([r[1] for r in done]):.0f}")
        print("变长最多的 10 个:")
        for f, o, n in sorted(more, key=lambda r: -(r[2] - r[1]))[:10]:
            print(f"   {o:>4} -> {n:>4} 音 ({n-o:+d})  {f[:66]}")
        if less:
            print("变短最多的 10 个:")
            for f, o, n in sorted(less, key=lambda r: r[2] - r[1])[:10]:
                print(f"   {o:>4} -> {n:>4} 音 ({n-o:+d})  {f[:66]}")
    if a.csv:
        with open(a.csv, "w", encoding="utf-8") as g:
            g.write("name\told\tnew\n")
            for f, o, n in rows:
                g.write(f"{f}\t{o}\t{n}\n")
        print(f"明细 -> {a.csv}")


if __name__ == "__main__":
    main()
