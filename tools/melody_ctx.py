# -*- coding: utf-8 -*-
"""查一个旋律串在语料里的**原始 token 上下文**(带八度 , ' 和减时线 _ 记号), 并打印曲名。
只报 LCS 达到查询长度(默认全中)的文件, 附前后各 N 个 token。
用法: py tools/melody_ctx.py 63231373 [--ctx 10] [--min 6]
"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TOK = re.compile(r"^[,']*[qsdh]*[,']*([0-9x])")


def tokens_with_marks(txt):
    """返回 [(干净数字, 带记号的原 token)] —— 先剥掉头部元数据。"""
    lines = [l.rstrip() for l in txt.splitlines()]
    if any(l.strip().lower().startswith("%--") for l in lines):
        i = next(i for i, l in enumerate(lines) if l.strip().lower().startswith("%--"))
        lines = lines[i + 1:]
    out = []
    for l in lines:
        s = l.strip()
        if not s or s.startswith("%"):
            continue
        if re.match(r"^[A-Za-z_]*\s*(title|type|tag|usertag|tagroute|transcriber|subtitle|MBID|Wikidata|L:|H:)", s):
            continue
        for t in s.split():
            m = TOK.match(t)
            if m:
                out.append((m.group(1), t))
    return out


def meta(txt):
    d = {}
    for k in ("title", "subtitle", "MBID", "Wikidata", "type"):
        m = re.search(rf"^\s*{k}\s*[:=]\s*(.+)$", txt, re.M | re.I)
        if m:
            d[k] = m.group(1).strip()
    return d


def lcs_pos(a, b):
    """返回 (长度, a 中起点, b 中起点)。"""
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
    ("GT手写", "train-work/gt/*.txt"),
]


def main():
    q = re.sub(r"[^0-9]", "", sys.argv[1])
    mn = int(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else len(q)
    ctx = int(sys.argv[sys.argv.index("--ctx") + 1]) if "--ctx" in sys.argv else 10
    print(f"查询 {q} ({len(q)} 音)  ctx={ctx}  只报 LCS>={mn}\n")
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
            toks = tokens_with_marks(txt)
            d = "".join(t[0] for t in toks)
            if len(d) < mn:
                continue
            L, i, j = lcs_pos(q, d)
            if L >= mn:
                rows.append((L, b[:-4], len(d), i, j, toks, meta(txt)))
        rows.sort(key=lambda x: (x[0] - x[2] / 100000.0), reverse=True)
        print(f"=== {label}  命中 {len(rows)} (按 LCS 长度/曲长 排) ===")
        for L, name, n, i, j, toks, m in rows[:6]:
            lo = max(0, j - ctx)
            hi = min(len(toks), j + L + ctx)
            raw = " ".join(t[1] for t in toks[lo:hi])
            mark = " " * len(" ".join(t[1] for t in toks[lo:j])) + "^" * max(1, len(" ".join(t[1] for t in toks[j:j + L])))
            oct_ = "".join("L" if t[1].startswith(",") else ("H" if t[1].startswith("'") else ".") for t in toks[j:j + L])
            print(f"  {L}/{len(q)}  {name[:46]}  共{n}音  位置{j}")
            print(f"      title={m.get('title','?')}  MBID={m.get('MBID','?')}")
            print(f"      八度: {oct_}   (L=低八度 ,  H=高八度 '  .=中音)")
            print(f"      原文: {raw}")
            print(f"            {mark}")
        if not rows:
            print("   (无)")
        print()


if __name__ == "__main__":
    main()
