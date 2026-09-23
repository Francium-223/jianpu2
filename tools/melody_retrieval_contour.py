# -*- coding: utf-8 -*-
"""留一版本检索:**加一路"间隔轮廓"匹配**, 看跨版本失败到底是"旋律不同"还是"只是换记法/移调"。

背景(实测): 查询取自版本 A、索引排除 A 时, 单段 11 音 Top-1 只有 51.3%; 拆开看
"两版这段完全一样"时是 100%, "两版有差异"时只有 12.5%。于是问题是:
  那些"有差异"的, 是**真不同的旋律**(那谁也救不了), 还是**同一段旋律换了调/换了记法**?
后者可以用**与绝对音级无关**的"间隔轮廓"(相邻音的音级差 mod 7)匹配救回来 —— 这正是
真人"凭记忆哼"时最可能发生的事(唱名记不全, 但走向记得住)。

报告三路 Top-1:
  * 唱名(绝对音级)  —— 现行口径
  * 间隔轮廓        —— 与调无关
  * 两者取优        —— 实际系统可以用"两路都查再合并"
并给出诊断: 精确匹配失败但轮廓匹配命中的比例(= 移调/换记法导致的失败占比)。

用法: py -3.13 tools/melody_retrieval_contour.py [--len 11] [--n 2] [--multi 1]
产物: train-work/retrieval_contour.tsv
"""
import glob
import os
import random
import re
import sys

sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import melody_oct as M

ARGS = sys.argv[1:]


def opt(name, default):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


L = int(opt("--len", 11))
N = int(opt("--n", 2))
MULTI = int(opt("--multi", 1))
SEED = int(opt("--seed", 20260922))
BENCH = opt("--bench", "train-work/bench_final100.txt")
SKIP = "0x"
BADWORD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")


def pitch_of(txt):
    e, _raw = M.enc(txt)
    return "".join(x[0] for x in e if x[0] not in SKIP)


def contour(p):
    """音高串 -> 间隔串: 相邻两音的音级差 mod 7(0=同音, 1=上行一级…)。与调无关。"""
    return "".join(str((int(b) - int(a)) % 7) for a, b in zip(p, p[1:]))


def group_of(name):
    base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", name.split("__")[0])
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def canon(names):
    def sc(n):
        base = n.split("__")[0]
        site = n.split("__")[-1].split("-")[0] if "__" in n else "?"
        return (BADWORD.search(base) is not None, 0 if site == "qupu123" else 1, len(base), n)
    return sorted(names, key=sc)[0]


print("1) 建索引(音高串 + 间隔串) ...")
groups = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        b = os.path.basename(f)[:-4]
        try:
            p = pitch_of(open(f, encoding="utf-8", errors="replace").read())
        except Exception:
            continue
        if len(p) < 7:
            continue
        c = contour(p)
        groups.setdefault(group_of(b), []).append(
            (b,
             np.frombuffer(p.encode("ascii", "ignore"), dtype=np.uint8),
             np.frombuffer(c.encode("ascii", "ignore"), dtype=np.uint8)))
print(f"   {len(groups)} 首歌 / {sum(len(v) for v in groups.values())} 份谱")

bench = [l.split("|")[0].strip() for l in open(BENCH, encoding="utf-8")
         if l.strip() and not l.startswith("#")]
have = []
for t in bench:
    key = t if t in groups else next((k for k in groups if k == t), None)
    if not key:
        continue
    names = [n for n, _p, _c in groups[key] if len(_p) >= L + 2]
    if len(names) >= 2:
        have.append((t, key))
print(f"2) 基准集 {len(bench)} 首, 有 >=2 个版本(可做留一)的 {len(have)} 首")


def wilson(k, n, z=1.96):
    if not n:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return 100 * (c - r) / d, 100 * (c + r) / d


def best_over(q_arr, drop, which):
    """按歌分组取最小错音数; which=1 音高串, which=2 间隔串。"""
    out = {}
    for g, ents in groups.items():
        best = None
        for n, p, c in ents:
            arr = p if which == 1 else c
            if n == drop or len(arr) < len(q_arr):
                continue
            w = np.lib.stride_tricks.sliding_window_view(arr, len(q_arr))
            m = int((w != q_arr).sum(axis=1).min())
            if best is None or m < best:
                best = m
        if best is not None:
            out[g] = best
    return out


def rank_of(sc, key):
    mine = sc.get(key)
    if mine is None:
        return None
    better = sum(1 for _g, m in sc.items() if m < mine)
    return better + 1


rnd = random.Random(SEED)
hits = {"pitch": {1: 0, 3: 0, 5: 0}, "contour": {1: 0, 3: 0, 5: 0}, "either": {1: 0, 3: 0, 5: 0}}
tot = 0
diag = {"miss_but_contour": 0, "miss_both": 0, "pitch_ok": 0}
for t, key in have:
    names = [n for n, _p, _c in groups[key] if len(_p) >= L + 2]
    A = canon(names)
    arr_p = dict((n, p) for n, p, _c in groups[key])[A]
    if len(arr_p) < L:
        continue
    for _ in range(N):
        qs = []
        for _m in range(MULTI):
            s = rnd.randrange(0, len(arr_p) - L + 1)
            qs.append("".join(chr(x) for x in arr_p[s:s + L]))
        q = qs[0]
        pq = np.frombuffer(q.encode("ascii", "ignore"), dtype=np.uint8)
        cq = np.frombuffer(contour(q).encode("ascii", "ignore"), dtype=np.uint8)
        sc_p = best_over(pq, A, 1)
        sc_c = best_over(cq, A, 2)
        rp = rank_of(sc_p, key)
        rc = rank_of(sc_c, key)
        tot += 1
        if rp is None:
            rp = 10 ** 9
        if rc is None:
            rc = 10 ** 9
        for k in (1, 3, 5):
            hits["pitch"][k] += int(rp <= k)
            hits["contour"][k] += int(rc <= k)
            hits["either"][k] += int(min(rp, rc) <= k)
        if rp <= 1:
            diag["pitch_ok"] += 1
        elif rc <= 1:
            diag["miss_but_contour"] += 1
        else:
            diag["miss_both"] += 1
    if tot and tot % 40 == 0:
        print(f"   ...{tot} 次查询", flush=True)

print(f"\n3) 留一版本 + 间隔轮廓: 长度 {L}, 每首 {N} 次(M={MULTI} 段), 查询 {tot}")
rows = []
for name, lab in (("pitch", "唱名(绝对音级)"), ("contour", "间隔轮廓(与调无关)"), ("either", "两路取优")):
    h = hits[name]
    parts = []
    for k in (1, 3, 5):
        lo, hi = wilson(h[k], tot)
        parts.append(f"Top-{k} {100.0*h[k]/max(tot,1):5.1f}% [{lo:.1f},{hi:.1f}]")
    print(f"   {lab:<16} " + "   ".join(parts))
    rows.append(f"{lab}\t{L}\t{MULTI}\t{tot}\t{h[1]}\t{h[3]}\t{h[5]}")
print(f"\n4) 诊断(单段唱名匹配): 命中 {diag['pitch_ok']}, "
      f"唱名没中但轮廓中了(疑似只是移调/换记法) {diag['miss_but_contour']}, "
      f"两路都没中(旋律确实不同) {diag['miss_both']}")
if tot:
    print(f"   唱名失败里, 有 {100.0*diag['miss_but_contour']/max(1,diag['miss_but_contour']+diag['miss_both']):.1f}% "
          f"其实只是移调/换记法 —— 这部分是可以救的")

with open("train-work/retrieval_contour.tsv", "a", encoding="utf-8") as f:
    if not os.path.exists("train-work/retrieval_contour.tsv") or os.path.getsize(
            "train-work/retrieval_contour.tsv") == 0:
        f.write("口径\t长度\t段数M\t查询数\tTop1\tTop3\tTop5\n")
    for r in rows:
        f.write(r + "\n")
print("-> train-work/retrieval_contour.tsv (追加)")
