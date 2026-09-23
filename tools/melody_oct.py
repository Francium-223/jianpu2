# -*- coding: utf-8 -*-
"""把每个音符编码成 (音级, 八度偏移) 再 LCS —— 严格匹配用户给的 `,6 3 2 3 1 3 ,7 3`
(低八度的 6 和 7 必须真的低八度)。记号解析: token = [qsdh]* [,']* 数字 [.,-]* ... 
注意 jianpu 里 `q,6` = 减时线(q) + 低八度(,) —— 前缀顺序两种都有, 所以先把 qsdh 剥掉再数 , 和 '。
用法: py tools/melody_oct.py ",6 3 2 3 1 3 ,7 3" [--min 8] [--ctx 6]
"""
import glob, os, re, sys
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TOKRE = re.compile(r"^([qsdh]*)([,']*)([0-9x])")


def enc(txt):
    """-> (编码串列表, 原 token 列表)。编码 = 音级 + 八度(如 '6-1' 表示低八度 6)。"""
    lines = [l.rstrip() for l in txt.splitlines()]
    if any(l.strip().lower().startswith("%--") for l in lines):
        i = next(i for i, l in enumerate(lines) if l.strip().lower().startswith("%--"))
        lines = lines[i + 1:]
    encs, raws = [], []
    for l in lines:
        s = l.strip()
        if not s or s.startswith("%"):
            continue
        if re.match(r"^[A-Za-z_]*\s*(title|type|tag|usertag|tagroute|transcriber|subtitle|MBID|Wikidata|L:|H:)", s):
            continue
        for t in s.split():
            m = TOKRE.match(t)
            if not m:
                continue
            pre, acc, dig = m.groups()
            off = acc.count(",") - acc.count("'")
            encs.append(f"{dig}{off:+d}")
            raws.append(t)
    return encs, raws


def meta(txt):
    d = {}
    for k in ("title", "subtitle", "MBID"):
        m = re.search(rf"^\s*{k}\s*[:=]\s*(.+)$", txt, re.M | re.I)
        if m:
            d[k] = m.group(1).strip()
    return d


def lcs_pos(a, b):
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


SOURCES = [
    ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
    ("我转写的", "batch-out/*.txt"),
    ("我转换的", "jianpu-db-out/scores/*.txt"),
]


def parse_query(s):
    """把 ',6 3 2 3 1 3 ,7 3' 解析成编码串。"""
    out = []
    for t in s.replace(",", " ,").split():
        m = re.match(r"^([,']*)([0-9x])$", t)
        if not m:
            continue
        acc, dig = m.groups()
        out.append(f"{dig}{acc.count(',') - acc.count(chr(39)):+d}")
    return out


def main():
    qs = sys.argv[1] if len(sys.argv) > 1 else ",6 3 2 3 1 3 ,7 3"
    q = parse_query(qs)
    mn = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else len(q)
    ctx = int(sys.argv[sys.argv.index("--ctx") + 1]) if "--ctx" in sys.argv else 6
    print(f"查询(带八度): {' '.join(q)}   共 {len(q)} 音   只报 LCS >= {mn}\n")
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
            e, raws = enc(txt)
            if len(e) < mn:
                continue
            L, i, j = lcs_pos(q, e)
            if L >= mn:
                rows.append((L, b[:-4], len(e), j, raws, meta(txt), e))
        rows.sort(key=lambda x: (-x[0], x[2]))
        print(f"=== {label}  命中 {len(rows)} ===")
        topn = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 10
        for L, name, n, j, raws, m, e in rows[:topn]:
            lo, hi = max(0, j - ctx), min(len(raws), j + L + ctx)
            seq = " ".join(raws[lo:hi])
            arm = " " * len(" ".join(raws[lo:j])) + "^" * len(" ".join(raws[j:j + L]))
            print(f"  {L}/{len(q)}  {name[:44]:46s} 共{n}音 @{j}  title={m.get('title','?')}")
            print(f"        {seq}")
            print(f"        {arm}")
        if not rows:
            print("   (无)")
        print()


if __name__ == "__main__":
    main()
