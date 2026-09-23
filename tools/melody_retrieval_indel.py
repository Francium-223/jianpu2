# -*- coding: utf-8 -*-
"""旋律检索评测(**容忍漏唱/多唱一个音**) —— 补上 melody_retrieval_eval.py 的最大缺口。

原评测只做 Hamming(等长替换), 可真人哼唱最常见的错不是"唱错音"而是**漏一个音/多一个字**。
做法(不动主评测器, 单独一份):
  真值 = 歌里 L 个音的一窗; 哼出来的 = 这窗 **删掉 1 个音**(长度 L-1) 或 **插进 1 个音**(长度 L+1),
  再可叠加 e 个替换错音。
  匹配端 = 用**查询本身 + 它的所有单删变体**去比对(覆盖 漏/多/无 三种情形):
    * 查询长度 L-1: 它自己就是真值的子序列 -> 长度 L-1 的 Hamming 能对上
    * 查询长度 L+1: 某个单删变体(长度 L)正好等于真值窗 -> 对得上
    * 查询长度 L  : 它自己
  得分 = 该歌所有版本、所有变体、所有窗口里的最小错音数; 排名按歌级(并列时目标歌排最前)。

用法: py -3.13 tools/melody_retrieval_indel.py [--len 11] [--sub 1] [--err 0] [--n 1] [--errmode neighbor]
产物: train-work/retrieval_indel.tsv
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
SUB = int(opt("--sub", 1))            # 漏/多唱的个数(1 = 允许一个音)
E = int(opt("--err", 0))              # 额外替换错音数
N = int(opt("--n", 1))
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
        groups.setdefault(group_of(b), []).append((b, np.frombuffer(d.encode("ascii", "ignore"),
                                                                    dtype=np.uint8)))
print(f"   {len(groups)} 首歌 / {sum(len(v) for v in groups.values())} 份谱")

bench = [l.split("|")[0].strip() for l in open(BENCH, encoding="utf-8")
         if l.strip() and not l.startswith("#")]
QUERY, have = {}, []
for t in bench:
    key = t if t in groups else next((k for k in groups if k == t), None)
    if not key:
        continue
    names = [n for n, a in groups[key] if len(a) >= L + 2]
    if not names:
        continue
    QUERY[t] = canon(names)
    have.append((t, key))
print(f"2) 基准集 {len(bench)} 首, 可用 {len(have)} 首")


def variants(q):
    """查询本身 + 所有单删变体(长度 len(q)、len(q)-1)。"""
    out = {q}
    if SUB >= 1:
        for i in range(len(q)):
            out.add(q[:i] + q[i + 1:])
    return sorted(out)


def score_q(q):
    """(歌 -> 最小错音数): 对每个变体算 Hamming, 取最小。"""
    out = {}
    for g, ents in groups.items():
        best = None
        for v in variants(q):
            va = np.frombuffer(v.encode("ascii", "ignore"), dtype=np.uint8)
            for _n, arr in ents:
                if len(arr) < len(va):
                    continue
                w = np.lib.stride_tricks.sliding_window_view(arr, len(va))
                m = int((w != va).sum(axis=1).min())
                if best is None or m < best:
                    best = m
        if best is not None:
            out[g] = best
    return out


def wilson(k, n, z=1.96):
    if n == 0:
        return 0.0, 0.0
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return (c - r) / d, (c + r) / d


rnd = random.Random(SEED)
hits = {1: 0, 3: 0, 5: 0}
pess = 0
ties = []
tot = 0
for ti, (t, key) in enumerate(have, 1):
    arr = dict(groups[key])[QUERY[t]]
    if len(arr) < L:
        continue
    for _ in range(N):
        s = rnd.randrange(0, len(arr) - L + 1)
        q = [chr(c) for c in arr[s:s + L]]
        if SUB:                                   # 漏/多唱一个音
            i = rnd.randrange(len(q))
            if rnd.random() < 0.5:
                del q[i]                          # 漏唱
            else:
                q.insert(i, rnd.choice("1234567"))  # 多唱
        for _ in range(E):                        # 额外替换错音
            i = rnd.randrange(len(q))
            if ERRMODE == "neighbor":
                cur = int(q[i])
                cand = [str(cur - 1), str(cur + 1)]
                cand = [c for c in cand if c in "1234567"]
                q[i] = rnd.choice(cand or [c for c in "1234567" if c != q[i]])
            else:
                q[i] = rnd.choice([c for c in "1234567" if c != q[i]])
        q = "".join(q)
        sc = score_q(q)
        mine = sc[key]
        better = sum(1 for g, m in sc.items() if m < mine)
        tie = sum(1 for g, m in sc.items() if m == mine)
        tot += 1
        ties.append(tie)
        pess += int(better + tie <= 1)
        for k in hits:
            hits[k] += int(better + 1 <= k)
    if ti % 20 == 0:
        print(f"   ...{ti}/{len(have)}  查询 {tot}", flush=True)

print(f"\n3) 真值 {L} 音, 允许漏/多唱 {SUB} 个音, 额外替换错音 {E} 个({ERRMODE}), 每首 {N} 个片段:")
parts = []
for k in (1, 3, 5):
    lo, hi = wilson(hits[k], tot)
    parts.append(f"Top-{k} {100.0*hits[k]/max(tot,1):5.1f}% [{100*lo:.1f},{100*hi:.1f}]")
print(f"  查询 {tot}   " + "   ".join(parts)
      + f"   | 并列下界 Top-1 {100.0*pess/max(tot,1):.1f}%  最近并列组平均 "
        f"{(sum(ties)/len(ties) if ties else 0):.1f} 首")
with open("train-work/retrieval_indel.tsv", "a", encoding="utf-8") as f:
    # **追加**而不是覆盖: 一次跑一个配置, 覆盖会把上一条结果冲掉(实测跑完两个配置只剩一行)✗
    if not os.path.exists("train-work/retrieval_indel.tsv") or os.path.getsize(
            "train-work/retrieval_indel.tsv") == 0:
        f.write("真值长度\t漏多唱\t额外错音\t错音模型\t查询数\tTop1\tTop3\tTop5\t并列下界Top1\t并列组均值\n")
    f.write(f"{L}\t{SUB}\t{E}\t{ERRMODE}\t{tot}\t{hits[1]}\t{hits[3]}\t{hits[5]}\t{pess}\t"
            f"{(sum(ties)/len(ties) if ties else 0):.2f}\n")
print("-> train-work/retrieval_indel.tsv (追加)")
