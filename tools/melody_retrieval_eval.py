# -*- coding: utf-8 -*-
"""旋律片段检索评测器 —— 模拟"哼一段旋律查歌"这一真实用法。

设计(2026-09-22 重写, 修掉两个会让数字失真的坑):
  ① **歌级检索, 不是文件级**: 库里同一首歌常有多份不同版本的谱, 查询片段命中"同一首歌的
     另一个版本"完全应该算对。原版把目标钉在某一个文件名上 -> 被同歌的其它版本抢掉名次,
     白白算失败 ✗。现在按**曲名分组**, 取组内最好成绩作为该歌的得分。
  ② **并列要交代**: 查询片段取自目标歌自己的谱, 所以目标歌的距离必为 0; 别的歌常含同一串
     音(同为 0)。原版并列按曲名排序 = 谁名字靠前谁赢 = 随机扣分 ✗。
     现在 rank = 1 + (严格更近的歌数), **并列时目标歌排最前**(宣传口径), 同时给出
     "并列按名次算"的 Top-1 下界。
  ③ 每个基准歌挑**最能代表这首歌**的那份谱做查询源(排除 吉他/钢琴/双谱/器乐 等改编版)。

  索引 = 全库已转写曲谱(batch-out + batch-out-dup)的音高串(丢八度/休止/认不出)。
  查询 = 从基准集每首歌的谱里随机截 L 个音, 可注入 e 个错音(模拟凭耳朵报错)。
  指标 = 歌级 Top-1/3/5 命中率 + Wilson 95% 置信区间。

用法:
  py -3.13 tools/melody_retrieval_eval.py --bench train-work/bench_final100.txt --len 11 --err 0 --n 5
  py -3.13 tools/melody_retrieval_eval.py --sweep       # L=7/9/11 × e=0/1/2 全表
产物: 屏幕输出 + train-work/retrieval_eval.tsv
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


BENCH = opt("--bench", "train-work/bench_final100.txt")
SWEEP = "--sweep" in ARGS
L = int(opt("--len", 9))
E = int(opt("--err", 0))
N = int(opt("--n", 5))
SEED = int(opt("--seed", 20260922))
ERRMODE = opt("--errmode", "rand")   # rand=随机换成任意其它音(狠) / neighbor=只错到相邻音级(像人哼)
SKIP = "0x"
SOURCES = ["batch-out/*.txt", "batch-out-dup/*.txt"]
BADWORD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")


def pitch_of(txt):
    e, _raw = M.enc(txt)
    return "".join(x[0] for x in e if x[0] not in SKIP)


def group_of(name):
    """'甜蜜蜜（乐队伴奏谱）__jianpucn-458351' -> '甜蜜蜜'(歌级分组键)。
    零宽字符必须先去掉 —— 源站有 `\\u200b算什么男人__qupu123-...` 这种, 不去掉就匹配不上基准集。"""
    base = name.split("__")[0]
    base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", base)
    # 空分组键会把一堆不相关的谱塌成同一首"歌", 所以空就退回原名
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def canon(names):
    """同一首歌的多个版本里挑"最能代表这首歌"的: 名字最短、非改编版、优先 qupu123。"""

    def sc(n):
        base = n.split("__")[0]
        site = n.split("__")[-1].split("-")[0] if "__" in n else "?"
        return (BADWORD.search(base) is not None, 0 if site == "qupu123" else 1, len(base), n)

    return sorted(names, key=sc)[0]


print("1) 建索引(全库音高串, 按曲名分组) ...")
groups = {}          # 歌名 -> [(文件名, np.array), ...]
for pat in SOURCES:
    for f in glob.glob(pat):
        b = os.path.basename(f)[:-4]
        try:
            d = pitch_of(open(f, encoding="utf-8", errors="replace").read())
        except Exception:
            continue
        if len(d) < 7:
            continue
        groups.setdefault(group_of(b), []).append((b, np.frombuffer(d.encode("ascii", "ignore"),
                                                                     dtype=np.uint8)))
n_ent = sum(len(v) for v in groups.values())
print(f"   索引 {len(groups)} 首歌 / {n_ent} 份谱")

bench = [l.split("|")[0].strip() for l in open(BENCH, encoding="utf-8")
         if l.strip() and not l.startswith("#")]
bench = [b for b in bench if b]


def find_group(title):
    if title in groups:
        return title
    for k in groups:
        if k == title or k.startswith(title) and len(k) - len(title) <= 2:
            return k
    return None


pairs = [(t, find_group(t)) for t in bench]
have = [(t, k) for t, k in pairs if k]
print(f"2) 基准集 {len(bench)} 首, 索引里能找到 {len(have)} 首")
# 覆盖率落盘: 交付说明要引用"基准集 N/100 首进了索引", 不能靠人工从日志里抄
with open("train-work/retrieval_coverage.txt", "w", encoding="utf-8") as _f:
    _f.write(f"{len(have)}\t{len(bench)}\t{len(groups)}\t{n_ent}\n")
missing = [t for t, k in pairs if not k]
if missing:
    print(f"   还不在索引里({len(missing)}): {'、'.join(missing[:20])}{' ...' if len(missing) > 20 else ''}")
if not have:
    sys.exit("索引里一首基准歌都没有, 停止")
for t, k in have[:5]:
    print(f"   例: {t} -> {canon([n for n, _a in groups[k]])}")

# 查询源: 每个基准歌挑一份代表谱
QUERY = {}
for t, k in have:
    names = [n for n, _a in groups[k] if len(_a) >= 7]
    if names:
        QUERY[t] = canon(names)
print(f"   查询源 {len(QUERY)} 首")


def wilson(k, n, z=1.96):
    if n == 0:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return (c - r) / d, (c + r) / d


def group_scores(qa):
    """每个歌组的最小错音数。"""
    out = {}
    for g, ents in groups.items():
        best = None
        for _n, arr in ents:
            if len(arr) < len(qa):
                continue
            w = np.lib.stride_tricks.sliding_window_view(arr, len(qa))
            m = int((w != qa).sum(axis=1).min())
            if best is None or m < best:
                best = m
        if best is not None:
            out[g] = best
    return out


def run(Lq, e, nq):
    rnd = random.Random(SEED)
    hits = {1: 0, 3: 0, 5: 0}
    pess = 0
    ties = []
    tot = 0
    for t, key in have:
        qn = QUERY.get(t)
        if not qn:
            continue
        arr = dict(groups[key])[qn]
        if len(arr) < Lq:
            continue
        starts = rnd.sample(range(0, len(arr) - Lq + 1), min(nq, len(arr) - Lq + 1))
        for s in starts:
            q = "".join(chr(c) for c in arr[s:s + Lq])
            if e:                                   # 注入错音(模拟凭耳朵报错)
                ql = list(q)
                for _ in range(e):
                    i = rnd.randrange(Lq)
                    if ERRMODE == "neighbor":
                        # 更像真人哼唱: 只错到**相邻音级**(1<->2<->3...), 不会从 1 跳到 5
                        cur = int(ql[i])
                        cand = [str(cur - 1), str(cur + 1)]
                        cand = [c for c in cand if c in "1234567"]
                        ql[i] = rnd.choice(cand or [c for c in "1234567" if c != ql[i]])
                    else:
                        ql[i] = rnd.choice([c for c in "1234567" if c != ql[i]])
                q = "".join(ql)
            qa = np.frombuffer(q.encode("ascii", "ignore"), dtype=np.uint8)
            sc = group_scores(qa)
            mine = sc[key]
            better = sum(1 for g, m in sc.items() if m < mine)
            tie = sum(1 for g, m in sc.items() if m == mine)
            rank_opt = better + 1
            rank_pess = better + tie
            tot += 1
            ties.append(tie)
            pess += int(rank_pess <= 1)
            for k in hits:
                hits[k] += int(rank_opt <= k)
    return tot, hits, pess, (sum(ties) / len(ties) if ties else 0.0)


ROWS = []


def report(Lq, e, tot, hits, pess=0, tie_avg=0.0):
    if not tot:
        print(f"  L={Lq} 错{e}: 无查询")
        return
    parts = []
    for k in (1, 3, 5):
        lo, hi = wilson(hits[k], tot)
        parts.append(f"Top-{k} {100.0*hits[k]/tot:5.1f}% [{100*lo:.1f},{100*hi:.1f}]")
    line = (f"  L={Lq:2d} 音  错{e} 个({ERRMODE})  查询{tot:4d}   " + "   ".join(parts)
            + f"   | 并列下界 Top-1 {100.0*pess/tot:4.1f}%  最近并列组平均 {tie_avg:.1f} 首")
    print(line, flush=True)
    ROWS.append(f"{Lq}\t{e}\t{ERRMODE}\t{tot}\t{hits[1]}\t{hits[3]}\t{hits[5]}\t{pess}\t{tie_avg:.2f}")


if SWEEP:
    print("\n3) 扫描(每首歌每种设置截 2 个片段):")
    for Lq in (7, 9, 11):
        for e in (0, 1, 2):
            globals()['L'] = Lq
            tot, hits, pess, tie = run(Lq, e, 2)
            report(Lq, e, tot, hits, pess, tie)
else:
    print(f"\n3) L={L} 错{E} 每首 {N} 个片段:")
    tot, hits, pess, tie = run(L, E, N)
    report(L, E, tot, hits, pess, tie)

with open("train-work/retrieval_eval.tsv", "w", encoding="utf-8") as f:
    f.write("L\t错音\t错音模型\t查询数\tTop1\tTop3\tTop5\t并列下界Top1\t并列组均值\n")
    f.write("\n".join(ROWS) + "\n")
print("\n-> train-work/retrieval_eval.tsv   (列: L / 错音数 / 错音模型 / 查询数 / Top1 / Top3 / Top5 / 并列下界 / 并列组均值)")
