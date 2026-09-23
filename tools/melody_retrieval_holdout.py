# -*- coding: utf-8 -*-
"""旋律检索:**留一版本(cross-version)** 评测 —— 把"拿谱对谱"的偏乐观量化掉。

为什么必须做这一步:
  主评测(melody_retrieval_eval.py)的查询片段取自目标谱**自己**, 所以目标歌必然有一个
  距离 0 的版本在索引里 —— 这模拟的是"拿谱对谱", 不是"凭记忆哼唱"。
  真实用户哼的是**脑子里的旋律**, 和库里那份谱的记法/版本可能不同(不同编配、不同转写噪声)。
  这里把查询源版本 A **从索引里排除**, 只留这首歌的**其它版本**(B/C…):
    * 还能找到 -> 说明检索对"版本差异"鲁棒 ✓
    * 找不到   -> 说明主评测的高分有多少来自"自匹配", 这个差值必须交代清楚

报告三件事:
  ① 有多少基准歌有 >=2 个版本(没有第二个版本就做不了这个实验, 单独计数)
  ② 留一版本后的 Top-1/3/5(歌级, 并列时目标歌排最前, 同时给下界)
  ③ **版本间差异**: 查询片段到"该歌其它版本"的最小错音数分布 —— 差异大就说明
     这个任务本身就难, 不是检索器差

用法:
  py -3.13 tools/melody_retrieval_holdout.py [--len 11] [--err 0] [--n 2] [--errmode neighbor]
产物: train-work/retrieval_holdout.tsv
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
E = int(opt("--err", 0))
N = int(opt("--n", 2))
MULTI = int(opt("--multi", 1))    # 多片段投票: 同一首歌取 M 段, 分数相加再排序
ERRMODE = opt("--errmode", "neighbor")
SEED = int(opt("--seed", 20260922))
BENCH = opt("--bench", "train-work/bench_final100.txt")
SKIP = "0x"
BADWORD = re.compile(r"吉他|钢琴|双谱|器乐|非洲|尤克里里|古筝|琵琶|二胡|笛|萨克斯|总谱|合唱")


def pitch_of(txt):
    e, _raw = M.enc(txt)
    return "".join(x[0] for x in e if x[0] not in SKIP)


def group_of(name):
    base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", name.split("__")[0])
    # 空分组键会把不相关的谱塌成同一首"歌"(45 个以《 开头的), 空就退回原名
    return re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()


def canon(names):
    def sc(n):
        base = n.split("__")[0]
        site = n.split("__")[-1].split("-")[0] if "__" in n else "?"
        return (BADWORD.search(base) is not None, 0 if site == "qupu123" else 1, len(base), n)
    return sorted(names, key=sc)[0]


print("1) 建索引 ...")
groups = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        b = os.path.basename(f)[:-4]
        try:
            d = pitch_of(open(f, encoding="utf-8", errors="replace").read())
        except Exception:
            continue
        if len(d) < 7:
            continue
        groups.setdefault(group_of(b), []).append(
            (b, np.frombuffer(d.encode("ascii", "ignore"), dtype=np.uint8)))
print(f"   {len(groups)} 首歌 / {sum(len(v) for v in groups.values())} 份谱")

bench = [l.split("|")[0].strip() for l in open(BENCH, encoding="utf-8")
         if l.strip() and not l.startswith("#")]
have1, have2 = 0, []
for t in bench:
    key = t if t in groups else next((k for k in groups if k == t), None)
    if not key:
        continue
    have1 += 1
    names = [n for n, a in groups[key] if len(a) >= L + 2]
    if len(names) >= 2:
        have2.append((t, key))
print(f"2) 基准集 {len(bench)} 首: 在索引里 {have1} 首, 其中**有 >=2 个版本**的 {len(have2)} 首")


def wilson(k, n, z=1.96):
    if not n:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return 100 * (c - r) / d, 100 * (c + r) / d


def score_q(q, drop):
    """按歌分组算最小错音数; `drop` 那个文件名(查询源版本)**从索引里排除**。"""
    out = {}
    qa = np.frombuffer(q.encode("ascii", "ignore"), dtype=np.uint8)
    for g, ents in groups.items():
        best = None
        for n, arr in ents:
            if n == drop or len(arr) < len(qa):
                continue
            w = np.lib.stride_tricks.sliding_window_view(arr, len(qa))
            m = int((w != qa).sum(axis=1).min())
            if best is None or m < best:
                best = m
        if best is not None:
            out[g] = best
    return out


def score_multi(qs, drop):
    """**多片段投票**: 对同一首歌哼 M 段, 每段各取最小错音数后**求和**再排序。

    为什么需要: 单片段时"另一首歌恰好含这 11 个音"(距离 0) 会压过"目标歌的另一个版本
    差 1 个音"(距离 1) —— 这是单片段固有的问题。真人哼唱会给多段旋律, 多段相加后
    真歌会因为"段段都接近"而胜出, 偶然撞上的一段说明不了问题。
    """
    tot = {}
    for q in qs:
        for g, m in score_q(q, drop).items():
            tot[g] = tot.get(g, 0) + m
    return tot


rnd = random.Random(SEED)
hits = {1: 0, 3: 0, 5: 0}
pess = 0
tot = 0
span = []          # 查询到"该歌其它版本"的最小错音数
# 按"版本是否一致"拆开统计: 一致(差异0)的片段本来就该找到; 不一致(差异>0)才是真考验
split = {"same": [0, 0], "diff": [0, 0]}     # [Top-1 命中数, 总数]
for t, key in have2:
    names = [n for n, a in groups[key] if len(a) >= L + 2]
    A = canon(names)
    others = [n for n in names if n != A]
    arr = dict(groups[key])[A]
    if len(arr) < L:
        continue
    for _ in range(N):
        # 取 M 段独立片段(多片段投票用); M=1 时就是原来的单片段
        qs = []
        for _m in range(MULTI):
            s = rnd.randrange(0, len(arr) - L + 1)
            q = [chr(c) for c in arr[s:s + L]]
            for _e in range(E):
                i = rnd.randrange(len(q))
                if ERRMODE == "neighbor":
                    cur = int(q[i])
                    cand = [c for c in (str(cur - 1), str(cur + 1)) if c in "1234567"]
                    q[i] = rnd.choice(cand or [c for c in "1234567" if c != q[i]])
                else:
                    q[i] = rnd.choice([c for c in "1234567" if c != q[i]])
            qs.append("".join(q))
        q = qs[0]
        # 该歌其它版本里最好的那个距离(说明版本差异有多大)
        qa = np.frombuffer(q.encode("ascii", "ignore"), dtype=np.uint8)
        b = None
        for n in others:
            a2 = dict(groups[key])[n]
            if len(a2) < len(qa):
                continue
            w = np.lib.stride_tricks.sliding_window_view(a2, len(qa))
            m = int((w != qa).sum(axis=1).min())
            if b is None or m < b:
                b = m
        if b is not None:
            span.append(b)
        sc = score_multi(qs, A) if MULTI > 1 else score_q(q, A)
        mine = sc.get(key)
        if mine is None:                    # 该歌除 A 外没有可比版本 -> 算未命中
            tot += 1
            continue
        better = sum(1 for g, m in sc.items() if m < mine)
        tie = sum(1 for g, m in sc.items() if m == mine)
        tot += 1
        pess += int(better + tie <= 1)
        for k in hits:
            hits[k] += int(better + 1 <= k)
        if b is not None:
            slot = split["same"] if b == 0 else split["diff"]
            slot[1] += 1
            slot[0] += int(better + 1 <= 1)

print(f"\n3) 留一版本: 真值 {L} 音, 额外错音 {E} 个({ERRMODE}), 查询源版本已从索引排除, "
      f"每首 {N} 次(M={MULTI} 段投票)")
parts = []
for k in (1, 3, 5):
    lo, hi = wilson(hits[k], tot)
    parts.append(f"Top-{k} {100.0*hits[k]/max(tot,1):5.1f}% [{lo:.1f},{hi:.1f}]")
print(f"  查询 {tot}   " + "   ".join(parts) + f"   | 并列下界 Top-1 {100.0*pess/max(tot,1):.1f}%")
if span:
    import statistics
    print(f"  版本差异: 查询片段到**同歌其它版本**的最小错音数 中位数 {statistics.median(span):.0f} "
          f"均值 {sum(span)/len(span):.1f} 最大 {max(span)}  (0 = 两个版本这段完全一样)")
    z = sum(1 for x in span if x == 0)
    print(f"            其中 {z}/{len(span)} = {100.0*z/len(span):.1f}% 是'两版这段完全相同'")
    for tag, lab in (("same", "两版完全一致"), ("diff", "两版有差异")):
        h, n = split[tag]
        if n:
            lo, hi = wilson(h, n)
            print(f"  其中 {lab}: {n} 次查询, Top-1 {100.0*h/n:5.1f}% [{lo:.1f},{hi:.1f}]")

with open("train-work/retrieval_holdout.tsv", "a", encoding="utf-8") as f:
    if not os.path.exists("train-work/retrieval_holdout.tsv") or os.path.getsize(
            "train-work/retrieval_holdout.tsv") == 0:
        f.write("长度\t额外错音\t错音模型\t片段数M\t查询数\tTop1\tTop3\tTop5\t并列下界Top1\t可留一版本曲数\t版本差异中位数\t同版一致Top1\t有差异Top1\n")
    med = int(__import__("statistics").median(span)) if span else -1
    _s = f"{100.0*split['same'][0]/split['same'][1]:.1f}" if split["same"][1] else "-"
    _d = f"{100.0*split['diff'][0]/split['diff'][1]:.1f}" if split["diff"][1] else "-"
    f.write(f"{L}\t{E}\t{ERRMODE}\t{MULTI}\t{tot}\t{hits[1]}\t{hits[3]}\t{hits[5]}\t{pess}\t{len(have2)}\t{med}\t{_s}\t{_d}\n")
print("-> train-work/retrieval_holdout.tsv (追加)")
