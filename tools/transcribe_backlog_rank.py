# -*- coding: utf-8 -*-
"""按**实测产物/GPU 小时**重排转写积压顺序, 并给出每条"为什么排这里"。

═══════════════════════════════════════════════════════════════════════════════════
为什么要有它(2026-10-08)
═══════════════════════════════════════════════════════════════════════════════════
`train-work/transcribe_backlog_order.txt` 原来基本是"按目录/子目录多少"排的。可是**目录数是虚的**:
`jianpucn-pop` 有 3 万多目录, 字母序开头连着几十个都是五线谱/吉他谱。排序要按**产出**排。

═══════════════════════════════════════════════════════════════════════════════════
⚠⚠ 三条实测把"过门率 = 产出效率"这个直觉彻底推翻了
═══════════════════════════════════════════════════════════════════════════════════
**① 各类结果的单位成本差一个量级 —— "非纯简谱"被拒几乎不花钱。**

    结果        条数    均秒     总秒        说明
    product    2710   15.20   41216
    texture     365   27.50   10053      **织体比成功还贵, 且零产出 —— 这才是真税**
    empty       276    3.10     854
    impure      136    0.022      3      **近乎免费**(纯度门在 CPU 上跑, 不碰模型)
    (数据源: `_analysis/transcribe_yield_census.py` 解析看门狗日志 3,000+ 条明细)

    所以"过门率低"**不等于**"每小时产出低": 被拒的那部分**不烧 GPU**。
    ===> 排序必须算
        `产物/小时 = 产物率 × 3600 / (产物×prod秒 + 织体×tex秒 + 空稿×3.1 + 非纯×0.02)`

**② 旧的过门率抽样是"按字母序取前 N 个", 是毒数据。** 随机重抽后差得很远 ——
    最狠的是 `jianpucn-pop`, 直接对同一个源量了两次(`_analysis/purity_sample_random.py`):

        jianpucn-pop  字母序前 40 个 ->  7.5% 纯简谱
        jianpucn-pop  随机    40 个 -> 39.5% 纯简谱      (**5 倍**)

    这就解释了生产上"jianpucn-pop 前 16 个全被拒"——那 16 个正是**字母序前 16 个**。
    拿它当"这个站 10.8% 能过门"是错的。`jp114-14/1` 早期那个 9.2% 是同一种病。

**③ 织体率由"目录内图数"决定, 而图数是**免费**的库存信息**(实测 jianpujia-shard, n=2286):

        图数      处理    产物    织体    产物率    产物均秒   织体均秒
        1 张     1789    1653     136    92.4%      16.9      29.3
        2 张       99      89       8    89.9%      17.2      37.1
        3-4 张     49      40       7    81.6%      15.5      26.9
        5-8 张    244     122     120    **50.0%**   16.2      27.2
        >8 张     105      61      40    58.1%      16.2      29.3

    **图多 = 又慢又容易是织体。** 所以站内排序取**图数升序(单图优先)** —— "多页优先"这个
    假设被实测**反过来**(顺带说: `transcribe_source.py:102` 的 `JP_MULTIPAGE` 生产上**没开**,
    全机环境变量为空, 所以生产是**单页模式**: 一个目录几页都只挑一张, "多页摊薄"根本不成立)。

用法:
    py -3.13 tools/transcribe_backlog_rank.py --report      # 只看表与对照, 不写文件
    py -3.13 tools/transcribe_backlog_rank.py --write       # 备份原顺序后重写
"""
import argparse
import io
import json
import os
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from batch_transcribe import safe_name      # noqa: E402  与转写侧同一个输出名口径

PREP = os.path.join(ROOT, "images-prep")
OUT = os.path.join(ROOT, "batch-out")
STATE = os.path.join(ROOT, "train-work", "transcribe_examined.txt")
ORDER = os.path.join(ROOT, "train-work", "transcribe_backlog_order.txt")
ORDER_BAK = os.path.join(ROOT, "train-work", "transcribe_backlog_order.orig.txt")
PURITY_JSON = os.path.join(ROOT, "train-work", "purity_by_source.json")
IMG = (".jpg", ".jpeg", ".png", ".gif", ".webp")

# ══════════════════════════════════════════════════════════════════════════════════
# 模型。每个系数都要有出处; 拿不到实测的必须标成先验, 并给出敏感度。
# ══════════════════════════════════════════════════════════════════════════════════
# 单位成本(秒)。实测自看门狗日志: 非纯简谱=0.022s, 空稿=3.1s。
SEC_EMPTY = 3.1
SEC_IMPURE = 0.022
# **每轮的固定开销**(秒): `>> python transcribe_source.py` 到第一条 `[1/N]` 之间 ——
# 含 python 启动 + `import torch` + 模型加载 + 第一次 pick_page。实测 22 个干净轮: 中位 **53**。
# 为什么要它: 低纯度源的条目**很便宜**, 一轮很快就跑完, 于是这 53 秒要摊到**更少的产物**上 ——
# 这是"低纯度"唯一真实的税(条目本身几乎不花钱, 见 SEC_IMPURE)。limit=300 时它约 1~2%,
# 但它让排序不至于把纯度当成完全无关。
SEC_ROUND_FIXED = 53.0
# 每轮最多交出去几个(= 看门狗 `-Limit`)与单轮硬上限(= `KillAfterMin` 秒)。
ROUND_LIMIT = 300
ROUND_KILL_SEC = 60 * 60.0

# **过纯度门之后**的桶系数 (产物率, 织体率)。jianpujia-shard 实测(n=2286), 作为结构先验给别的站用。
BUCKET = {
    "1":   (0.924, 0.076),
    "2":   (0.899, 0.081),
    "3-4": (0.816, 0.143),
    "5-8": (0.500, 0.492),
    ">8":  (0.581, 0.381),
}
# fysongs 自己实测过(n=175), 织体率低一个量级 —— 有实测就用自己的, 不用先验。
BUCKET_OVERRIDE = {
    "fysongs": {"1": (0.992, 0.008), "3-4": (0.980, 0.020)},
}
# 站的产物/织体均秒。前两个是实测; jp114 的产物秒来自 21 首探针(织体秒借用 jianpujia);
# jianpucn / qupu123 两道都拿不到(织体门必须跑模型, 而现在 GPU 上只许一个转写实例), 用 jianpujia 先验。
SITE_COST = {
    "jianpujia": (16.8, 28.6, "实测 n=2286"),
    "fysongs":   (11.6, 35.0, "实测 n=175"),
    "jp114":     (13.0, 28.6, "产物秒=21 首探针; 织体秒=jianpujia 先验"),
    "jianpucn":  (16.8, 28.6, "先验(jianpujia)"),
    "qupu123":   (16.8, 28.6, "先验(jianpujia)"),
}
DEFAULT_COST = (16.8, 28.6, "先验(jianpujia)")
# 没有随机纯度抽样的站, 给一个保守先验(**不许插到有实测的源前面**的排序原则由 per_hour 自然保证)。
PURITY_DEFAULT = 0.20


def site_of(src):
    for k in ("jianpujia", "jianpucn", "qupu123", "jp114", "fysongs"):
        if src == k or src.startswith(k + "-"):
            return k
    return ""


def page_bucket(n):
    if n <= 1:
        return "1"
    if n == 2:
        return "2"
    if n <= 4:
        return "3-4"
    if n <= 8:
        return "5-8"
    return ">8"


def has_image(d):
    try:
        names = os.listdir(d)
    except OSError:
        return False
    for n in names:
        if not n.lower().endswith(IMG):
            continue
        try:
            if os.path.getsize(os.path.join(d, n)) > 0:
                return True
        except OSError:
            pass
    return False


def load_seen():
    seen = set()
    if not os.path.isfile(STATE):
        return seen
    with io.open(STATE, encoding="utf-8", errors="replace") as f:
        for ln in f:
            p = ln.rstrip("\n").split("\t")
            if len(p) == 2:
                seen.add((p[0], p[1]))
    return seen


def load_purity():
    """`train-work/purity_by_source.json`(由 `_analysis/purity_sample_random.py` 生成)。"""
    if not os.path.isfile(PURITY_JSON):
        return {}
    try:
        with io.open(PURITY_JSON, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def inventory(srcs, seen):
    """按 pick 的**同一套**口径算每个源的"还有多少可交": 有图 且 无 batch-out 且 未记账。"""
    rows = []
    for src in srcs:
        d = os.path.join(PREP, src)
        if not os.path.isdir(d):
            continue
        fresh = []
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for name in names:
            full = os.path.join(d, name)
            if not os.path.isdir(full) or not has_image(full):
                continue
            if os.path.exists(os.path.join(OUT, safe_name(name) + ".txt")):
                continue
            if (src, name) in seen:
                continue
            try:
                n_img = len([f for f in os.listdir(full) if f.lower().endswith(IMG)])
            except OSError:
                n_img = 1
            fresh.append((name, n_img))
        if fresh:
            rows.append((src, fresh))
    return rows


def predict(src, fresh, purity):
    """按成本模型算这个源的 产物率 / 秒每首 / 产物每小时, 并给敏感度带。"""
    site = site_of(src)
    prod_sec, tex_sec, cost_src = SITE_COST.get(site, DEFAULT_COST)
    btab = dict(BUCKET)
    btab.update(BUCKET_OVERRIDE.get(site, {}))

    pv = purity.get(src)
    if pv and pv.get("rate") is not None:
        p = float(pv["rate"])
        p_n = int(pv.get("n") or 0)
        p_conf = "按源随机抽样 n=%d%s" % (p_n, "(站池化)" if pv.get("pooled") else "")
    else:
        p = PURITY_DEFAULT
        p_n = 0
        p_conf = "**无随机抽样**, 保守先验 %.0f%%" % (100 * p)

    buckets = {}
    for _n, k in fresh:
        buckets[page_bucket(k)] = buckets.get(page_bucket(k), 0) + 1
    tot = len(fresh)

    def calc(tex_scale):
        prod_rate = sec = 0.0
        for b, c in buckets.items():
            r, t = btab[b]
            t = min(1.0, t * tex_scale)
            w = c / tot
            prod_rate += w * p * r
            sec += w * (p * (r * prod_sec + t * tex_sec) + (1 - p) * SEC_IMPURE)
        return prod_rate, sec

    rate, sec = calc(1.0)
    _r_hi, sec_hi = calc(0.0)          # 织体率=0 的乐观上界(少烧钱)
    _r_lo, sec_lo = calc(2.0)          # 织体率翻倍的悲观下界(多烧钱)

    def round_yield(rr, ss):
        """按**真实轮结构**折算产物/小时: 一轮 = 固定开销 + N×每首秒, N 受 -Limit 与单轮上限双重约束。
        被单轮上限截断时, 看门狗会**立刻接下一轮**(`continue`), 所以固定开销每轮都要付一次。"""
        if ss <= 0:
            return 0.0
        n = min(ROUND_LIMIT, tot)
        if SEC_ROUND_FIXED + n * ss > ROUND_KILL_SEC:
            n = max(1, int((ROUND_KILL_SEC - SEC_ROUND_FIXED) / ss))
            spent = ROUND_KILL_SEC
        else:
            spent = SEC_ROUND_FIXED + n * ss
        return n * rr * 3600.0 / spent

    per_hour = round_yield(rate, sec)
    return dict(src=src, site=site, n_fresh=tot, buckets=buckets, purity=p, p_n=p_n,
                p_conf=p_conf, rate=rate, sec=sec, per_hour=per_hour,
                band=(round_yield(rate, sec_lo), round_yield(rate, sec_hi)),
                cost_src=cost_src, single=buckets.get("1", 0))


def load_order(path):
    if not os.path.isfile(path):
        return []
    out = []
    with io.open(path, encoding="utf-8") as f:
        for ln in f:
            s = ln.split("\t")[0].strip()
            if s and not s.startswith("#"):
                out.append(s)
    return out


def report(rows):
    print("=" * 132)
    print("转写积压: 各源库存 × 实测成本模型(排序依据 = 产物/GPU 小时)")
    print("=" * 132)
    print("%-26s %7s %6s %7s %7s %8s %8s %9s %10s %-22s" %
          ("源", "待交", "单图", "1张", "5-8张", "纯度率", "产物率", "秒/首", "产物/h", "纯度依据"))
    print("-" * 132)
    for r in rows:
        b = r["buckets"]
        print("%-26s %7d %6d %7d %7d %7.1f%% %7.1f%% %9.2f %10.1f %-22s" %
              (r["src"], r["n_fresh"], r["single"], b.get("1", 0), b.get("5-8", 0),
               100 * r["purity"], 100 * r["rate"], r["sec"], r["per_hour"], r["p_conf"]))
    print("-" * 132)
    print("合计待交 %d 个目录" % sum(r["n_fresh"] for r in rows))
    print()
    print("成本系数出处:")
    for k, (ps, ts, c) in SITE_COST.items():
        print("  %-10s 产物 %5.1f 秒/首 · 织体 %5.1f 秒/首 · %s" % (k, ps, ts, c))
    print("  非纯简谱 %.3f 秒/首(实测: 136 条共 3 秒, CPU 纯度门不碰模型) · 空稿 %.1f 秒/首"
          % (SEC_IMPURE, SEC_EMPTY))
    print("  ⚠ **最大不确定**是 jianpucn / qupu123 的**织体率**(织体门必须跑模型, 现在不能测),")
    print("    它们借用 jianpujia 的图数分桶先验。下表给敏感度带(织体率 ×0 与 ×2)。")


def simulate(rows, top):
    """模拟 pick 的真实消费: 逐源吃干净, 源内**单图优先**; 每轮付一次固定开销、受单轮上限约束。"""
    prod = secs = 0.0
    n = 0
    per_src = {}
    for r in rows:
        if n >= top:
            break
        order = r["fresh_sorted"]
        take = order[:min(ROUND_LIMIT, len(order), top - n)]
        if not take:
            continue
        base = dict(BUCKET)
        base.update(BUCKET_OVERRIDE.get(r["site"], {}))
        ps, ts, _c = SITE_COST.get(r["site"], DEFAULT_COST)
        cost = 0.0
        for _name, k in take:
            rr, tt = base[page_bucket(k)]
            prod += r["purity"] * rr
            cost += r["purity"] * (rr * ps + tt * ts) + (1 - r["purity"]) * SEC_IMPURE
        secs += SEC_ROUND_FIXED + cost
        n += len(take)
        per_src[r["src"]] = per_src.get(r["src"], 0) + len(take)
    hours = secs / 3600.0
    return dict(n=n, prod=prod, hours=hours, per_hour=(prod / hours) if hours else 0.0,
                per_src=per_src)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="重写 train-work/transcribe_backlog_order.txt")
    ap.add_argument("--top", type=int, default=500, help="对照统计前几个交出去的目录")
    ap.add_argument("--limit", type=int, default=300)
    ap.add_argument("--topn", type=int, default=40, help="打印前几个源")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    old_order = load_order(ORDER_BAK) or load_order(ORDER)
    all_srcs = list(dict.fromkeys(old_order + sorted(
        d for d in os.listdir(PREP) if os.path.isdir(os.path.join(PREP, d)))))
    seen = load_seen()
    purity = load_purity()
    inv = inventory(all_srcs, seen)
    rows = []
    for s, fr in inv:
        r = predict(s, fr, purity)
        r["fresh_sorted"] = sorted(fr, key=lambda t: (t[1], t[0]))
        rows.append(r)

    by_src = {r["src"]: r for r in rows}
    old_rows = [by_src[s] for s in old_order if s in by_src]
    old_rows += [r for r in rows if r["src"] not in set(old_order)]
    ranked = sorted(rows, key=lambda r: (-r["per_hour"], -r["n_fresh"], r["src"]))

    report(ranked)
    print()
    print("=" * 132)
    print("新排序(按 产物/小时 降序; 站内单图优先)  ★ = 纯度有随机实测")
    print("=" * 132)
    for i, r in enumerate(ranked[:a.topn], 1):
        star = "★" if r["p_n"] else " "
        print("%3d.%s %-26s 待交 %6d · 纯度 %5.1f%% · 产物率 %5.1f%% · %5.2f 秒/首 · **%7.1f 产物/小时**"
              " · 敏感度 %5.0f..%5.0f · %s"
              % (i, star, r["src"], r["n_fresh"], 100 * r["purity"], 100 * r["rate"],
                 r["sec"], r["per_hour"], r["band"][0], r["band"][1], r["p_conf"]))
    if len(ranked) > a.topn:
        print("    ... 共 %d 个源" % len(ranked))

    s_new = simulate(ranked, a.top)
    s_old = simulate(old_rows, a.top)
    print()
    print("=" * 132)
    print("前 %d 首的预期产出对照(**同口径**: 同一套成本模型, 只换消费顺序)" % a.top)
    print("=" * 132)
    print("%-12s %8s %12s %12s %16s" % ("顺序", "目录数", "预期产物", "预期小时", "预期产物/小时"))
    print("-" * 66)
    print("%-12s %8d %12.0f %12.1f %16.1f" % ("旧(原文件)", s_old["n"], s_old["prod"],
                                              s_old["hours"], s_old["per_hour"]))
    print("%-12s %8d %12.0f %12.1f %16.1f" % ("新(本次)", s_new["n"], s_new["prod"],
                                              s_new["hours"], s_new["per_hour"]))
    if s_old["per_hour"]:
        print("提升 %.1f%%(预期产物/小时 %.1f -> %.1f)"
              % (100.0 * (s_new["per_hour"] / s_old["per_hour"] - 1),
                 s_old["per_hour"], s_new["per_hour"]))
    for tag, s in (("新", s_new), ("旧", s_old)):
        print("前 %d 首落在哪些源(%s顺序): %s" % (a.top, tag,
              " · ".join("%s %d" % (k, v) for k, v in
                         sorted(s["per_src"].items(), key=lambda kv: -kv[1])[:6])))

    if a.write:
        if os.path.isfile(ORDER) and not os.path.isfile(ORDER_BAK):
            with io.open(ORDER, encoding="utf-8") as f:
                orig = f.read()
            with io.open(ORDER_BAK, "w", encoding="utf-8", newline="\n") as f:
                f.write(orig)
            print("\n原顺序已备份 -> %s" % ORDER_BAK)
        lines = [
            "# 转写积压优先顺序 —— 按**实测产物/GPU 小时**降序; 站内由 pick 按图数升序(单图优先)消费。",
            "# 生成: tools/transcribe_backlog_rank.py --write",
            "# 列: <源目录>\t<产物/小时>\t<产物率>\t<秒/首>\t<纯度样本量>\t<纯度依据>\t<出处>",
            "# 原始(按目录数)顺序保留在同目录 transcribe_backlog_order.orig.txt, 回退直接改名覆盖。",
            "# ⚠ 关键口径: **非纯简谱被拒几乎不花 GPU 时间**(实测 0.022 秒/首), 所以「过门率低」",
            "#   不等于「每小时产出低」; 真正的税是**织体**(实测 27.5 秒/首且零产出), 而织体率",
            "#   由**目录内图数**决定(1 张 7.6% vs 5-8 张 49.2%) —— 所以站内单图优先。",
            "# ⚠ 旧的过门率抽样是**按字母序取前 N 个**(毒数据): jianpucn-pop 字母序前 40 = 7.5% 纯,",
            "#   随机 40 = 39.5% 纯(5 倍差)。本清单的纯度一律取 `_analysis/purity_sample_random.py` 的随机抽样。",
        ]
        for r in ranked:
            why = ("纯度 %.1f%%(%s); 秒/首 %.2f = 纯度×(产物%.1f/织体%.1f 秒)+非纯%.3f; 图数 %s; %s"
                   % (100 * r["purity"], r["p_conf"], r["sec"],
                      SITE_COST.get(r["site"], DEFAULT_COST)[0],
                      SITE_COST.get(r["site"], DEFAULT_COST)[1], SEC_IMPURE,
                      " ".join("%s:%d" % (k, v) for k, v in sorted(r["buckets"].items())),
                      r["cost_src"]))
            lines.append("%s\t%.1f\t%.4f\t%.2f\t%d\t%s\t%s"
                         % (r["src"], r["per_hour"], r["rate"], r["sec"], r["p_n"],
                            r["p_conf"].replace("\t", " "), why.replace("\t", " ")))
        os.makedirs(os.path.dirname(ORDER), exist_ok=True)
        with io.open(ORDER, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print("已写 %s(%d 个源)" % (ORDER, len(ranked)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
