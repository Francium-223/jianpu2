# -*- coding: utf-8 -*-
"""旋律检索(稳健版): 对每首歌求与查询数字串的**最长公共子串**, 按长度排序。

比"整串模糊匹配"稳: 语料转写有错(约 36%), 整串匹配会因为一两处错就全丢;
而最长公共子串能告诉你"这首歌里有段多长的旋律跟你给的完全一样"。
用法: py tools/melody_lcs.py 33565653253 [--min 5] [--top 25]
"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")


def digits_of(path):
    out = []
    for t in open(path, encoding="utf-8", errors="replace").read().split():
        m = re.match(r"^[,']*[qsdh]*[,']*([1-7])", t)
        if m:
            out.append(m.group(1))
    return "".join(out)


def lcs_with_pos(a, b):
    """最长公共子串(dp 滚动数组), 返回 (长度, a中起点, b中起点)。"""
    if not a or not b:
        return 0, 0, 0
    prev = [0] * (len(b) + 1)
    best = (0, 0, 0)
    for i in range(1, len(a) + 1):
        cur = [0] * (len(b) + 1)
        ai = a[i - 1]
        for j in range(1, len(b) + 1):
            if ai == b[j - 1]:
                cur[j] = prev[j - 1] + 1
                if cur[j] > best[0]:
                    best = (cur[j], i - cur[j], j - cur[j])
        prev = cur
    return best


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    q = re.sub(r"[^1-7]", "", sys.argv[1])
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 25
    mn = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 5
    print(f"查询: {q} ({len(q)} 音)  —— 按最长公共子串排序, 只列 >= {mn} 音的")
    rows = []
    for f in glob.glob("batch-out/*.txt"):
        b = os.path.basename(f)
        if b in ("progress.txt", "skipped.txt"):
            continue
        d = digits_of(f)
        if len(d) < mn:
            continue
        L, pa, pb = lcs_with_pos(q, d)
        if L >= mn:
            rows.append((L, b[:-4], len(d), q[pa:pa + L], pb))
    rows.sort(key=lambda x: (-x[0], x[2]))
    print(f"命中 {len(rows)} 首")
    for L, name, n, seg, pb in rows[:top]:
        cov = f"{L}/{len(q)}"
        print(f"   {L:2d}音 ({cov:>6})  {name[:50]:52s} 共{n:4d}音 @{pb}")
        print(f"                     匹配段: {seg}")


if __name__ == "__main__":
    main()
