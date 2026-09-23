# -*- coding: utf-8 -*-
"""旋律检索: 在本地语料里按数字串反查歌名。

忽略时值/八度/附点, 只比数字序列(连续子串匹配)。
用法:
  py tools/melody_search.py 33565653253
  py tools/melody_search.py 33565653253 --fuzzy 1     # 允许 1 处不同
  py tools/melody_search.py 33565653253 --top 30
"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")


def digits_of(path):
    """把谱的 token 序列压成纯数字串(丢掉时值/八度/附点/休止)。"""
    out = []
    for t in open(path, encoding="utf-8", errors="replace").read().split():
        m = re.match(r"^[,']*[qsdh]*[,']*([1-7])", t)
        if m:
            out.append(m.group(1))
    return "".join(out)


def search(q, fuzzy=0, top=20, with_rest=0):
    hits = []
    for f in glob.glob("batch-out/*.txt"):
        b = os.path.basename(f)
        if b in ("progress.txt", "skipped.txt"):
            continue
        d = digits_of(f)
        if len(d) < len(q):
            continue
        if fuzzy == 0:
            pos = d.find(q)
            if pos >= 0:
                hits.append((b[:-4], len(d), pos, q, 0))
            continue
        best = None
        for i in range(len(d) - len(q) + 1):
            win = d[i:i + len(q)]
            diff = sum(1 for a, c in zip(win, q) if a != c)
            if diff <= fuzzy and (best is None or diff < best[1]):
                best = (i, diff)
                if diff == 0:
                    break
        if best:
            hits.append((b[:-4], len(d), best[0], d[best[0]:best[0] + len(q)], best[1]))
    # 完全匹配优先, 然后按不同数、谱长排序
    hits.sort(key=lambda x: (x[4], -len(x[3]), x[1]))
    return hits


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    q = re.sub(r"[^1-7]", "", sys.argv[1])
    fuzzy = int(sys.argv[sys.argv.index("--fuzzy") + 1]) if "--fuzzy" in sys.argv else 0
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 20
    print(f"查询数字串: {q}  ({len(q)} 个音)" + (f"  允许 {fuzzy} 处不同" if fuzzy else ""))
    hits = search(q, fuzzy, top)
    print(f"命中 {len(hits)} 首" + (f" (只显示前 {top})" if len(hits) > top else ""))
    for name, n, pos, win, diff in hits[:top]:
        mark = "  ✓" if diff == 0 else f"  差{diff}处"
        print(f"   {name[:54]:56s} 共{n:4d}音 @{pos:4d}{mark}")
    if not hits:
        print("   (无 —— 试 --fuzzy 1, 或换一段旋律)")


if __name__ == "__main__":
    main()
