# -*- coding: utf-8 -*-
"""多源旋律检索: 不只搜自己转写的语料, 还搜**人工校对的本地资源**:
  1) 用户的 jianpu-db 仓库 (927 份人工校对曲谱)
  2) train-work/gt/ 的 .txt 与 .ly (人手写)
  3) jianpu-db-out/scores (我转换的)
  4) batch-out (我转写的)
按最长公共子串排序。
用法: py tools/melody_all.py 33565653253 [--min 6]
"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")


def digits_from_text(txt):
    """从任意曲谱文本里抽数字序列: 取 %-- 之后的行, 只认音符 token。"""
    lines = [l.strip() for l in txt.splitlines()]
    if any(l.lower().startswith("%--") for l in lines):
        i = next(i for i, l in enumerate(lines) if l.lower().startswith("%--"))
        lines = lines[i + 1:]
    out = []
    for l in lines:
        if l.startswith("%") or re.match(r"^\s*(title|type|tag|usertag|tagroute|transcriber|subtitle|MBID|Wikidata|L:|H:)", l):
            continue
        for t in l.split():
            # **必须把休止符 0 也收进来** —— 原来只认 [1-7], 0 被整段丢掉, 检索就会
            # **跨过休止符**拼出假匹配: 实测《赞家园》里
            #   …5 2 1 7 6 5 [0] 5 2…  被读成 …5 2 1 7 6 5 5 2… -> 误配用户问的 52176552 ✗
            # 收进 0 之后, 查询串里没有 0 就对不上, 假匹配自然消失 ✓。
            m = re.match(r"^[,']*[qsdh]*[,']*([0-9x])", t)
            if m:
                out.append(m.group(1))
    return "".join(out)


def lcs(a, b):
    if not a or not b:
        return 0, ""
    prev = [0] * (len(b) + 1)
    best = (0, "")
    for i in range(1, len(a) + 1):
        cur = [0] * (len(b) + 1)
        ai = a[i - 1]
        for j in range(1, len(b) + 1):
            if ai == b[j - 1]:
                cur[j] = prev[j - 1] + 1
                if cur[j] > best[0]:
                    best = (cur[j], a[i - cur[j]:i])
        prev = cur
    return best


SOURCES = [
    ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("GT手写", "train-work/gt/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
    ("我转写的", "batch-out/*.txt"),
]

def main():
    q = re.sub(r"[^1-7]", "", sys.argv[1]) if len(sys.argv) > 1 else ""
    mn = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 6
    if not q:
        print(__doc__); return
    print(f"查询: {q} ({len(q)} 音)   只列公共子串 >= {mn} 音\n")
    for label, pat in SOURCES:
        rows = []
        for f in glob.glob(pat):
            b = os.path.basename(f)
            if b in ("progress.txt", "skipped.txt"):
                continue
            try:
                txt = open(f, encoding="utf-8", errors="replace").read()
            except Exception:
                continue
            d = digits_from_text(txt) if ("scores" in pat or "gt" in pat) else \
                "".join(m.group(1) for m in
                        (re.match(r"^[,']*[qsdh]*[,']*([1-7])", t) for t in txt.split()) if m)
            if len(d) < mn:
                continue
            L, seg = lcs(q, d)
            if L >= mn:
                rows.append((L, b[:-4] if b.endswith(".txt") else b, len(d), seg))
        rows.sort(key=lambda x: (-x[0], x[2]))
        print(f"=== {label} ({pat})  命中 {len(rows)} ===")
        for L, name, n, seg in rows[:8]:
            print(f"   {L:2d}/{len(q)}  {name[:48]:50s} 共{n:4d}音   段:{seg}")
        if not rows:
            print("   (无)")
        print()

if __name__ == "__main__":
    main()
