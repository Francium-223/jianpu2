# -*- coding: utf-8 -*-
"""音程轮廓检索 —— 对"人凭耳朵哼一段"最合适的匹配方式:
   * **换调不变**: 只比相邻音的音程(取最短带符号距离, -6..+6), 不比绝对音级。
   * **休止/认不出的音直接跳过**, 不打断乐句。
   * 允许 e 个音程不匹配。
为什么需要它: 用户报的 `551122531` 在库里按"绝对音级"9/9 全空, 但很可能只是**调不同**
(谱上写成别的音级) —— 绝对音级匹配对这种情况天然失效 ✗。
用法: py -3.13 tools/melody_contour.py 551122531 [--max 1] [--top 20]
"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import melody_oct as M

q = sys.argv[1]
MAXM = int(sys.argv[sys.argv.index("--max") + 1]) if "--max" in sys.argv else 1
TOP = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 20
SKIP = "0x"
SEMI = {"1": 0, "2": 2, "3": 4, "4": 5, "5": 7, "6": 9, "7": 11}


def intervals(notes):
    """音级串 -> 带符号最短音程串(可打印字符)。"""
    out = []
    for a, b in zip(notes, notes[1:]):
        d = (SEMI[b] - SEMI[a]) % 12
        if d > 6:
            d -= 12
        out.append(chr(ord("A") + d + 6))      # -6..6 -> 'A'..'M'
    return "".join(out)


qi = intervals(q)
print(f"查询 {q} ({len(q)} 音)  音程串 {qi}   允许错 {MAXM} 个音程\n")

SOURCES = [("我转写的", "batch-out/*.txt"), ("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
           ("我转换的", "jianpu-db-out/scores/*.txt")]
rows = []
for label, pat in SOURCES:
    for f in glob.glob(pat):
        b = os.path.basename(f)
        if b in ("progress.txt", "skipped.txt"):
            continue
        try:
            txt = open(f, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        e, _raw = M.enc(txt)
        # 只留 1-7: 休止 0 / 认不出 x **以及 OCR 偶发的 8、9** 都要剔掉, 否则 SEMI 查表 KeyError
        d = "".join(x[0] for x in e if x[0] in SEMI)
        if len(d) < len(q):
            continue
        di = intervals(d)
        if len(di) < len(qi):
            continue
        best, bi = 99, -1
        for i in range(len(di) - len(qi) + 1):
            w = di[i:i + len(qi)]
            m = sum(1 for a, c in zip(qi, w) if a != c)
            if m < best:
                best, bi = m, i
                if best == 0:
                    break
        if best <= MAXM:
            rows.append((best, len(d), b[:-4], bi, di, d))
rows.sort(key=lambda x: (x[0], x[1]))
print(f"命中(音程错 <= {MAXM}): {len(rows)}\n")
for best, n, name, bi, di, d in rows[:TOP]:
    lo = max(0, bi - 4)
    print(f"  错{best}  {name[:46]:48s} 共{n:5d}音")
    print(f"       音程: {di[lo:bi + len(qi) + 6]}   音级: {d[lo:bi + len(q) + 6]}")
print("\n注: 音程取'最短带符号距离', 只对**级进为主**的旋律可靠; 大跳多的地方会有假阳性。")
