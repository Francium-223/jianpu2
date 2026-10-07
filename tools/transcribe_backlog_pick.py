# -*- coding: utf-8 -*-
"""**只读挑选 + 记账**本轮的转写目标 —— 供 `tools/transcribe_watchdog.ps1` 每轮调用。

为什么需要它(2026-10-06 实测, 两条都是真踩过的坑):
  1. `transcribe_source.py` 一次只吃**一个**源目录; 而它的目录模式是"排序后取前 N 个"
     (`sorted(glob('<SRC>/*'))[:LIMIT]`) —— 于是每轮都从**字母序开头**重扫。
     jianpucn-pop 开头连着 60 个都是"非纯简谱"(吉他谱), 实测一轮 `完成 7/60`、**产出 0 份**,
     下一轮还是这 60 个 —— 看门狗会永远原地空转。
  2. 就算换成名单模式, 也得记住"哪些目录已经交出去过了", 否则照样重复。

所以本工具的活是: 按 `train-work/transcribe_backlog_order.txt`(积压优先顺序) 找到**第一个还有
未交付目录**的源, 从里面取前 `--limit` 个**没转过、也没交出去过**的目录, 写成一份**名单文件**;
`transcribe_source.py <名单文件>` 正好是它已经支持的用法(每行一个目录名, 跨源按名字找)。
本轮跑完由看门狗回调 `--commit` 把这批名字记进 `--state`。

状态文件(`train-work/transcribe_examined.txt`)一行一条: `源目录<TAB>谱目录名`。
**为什么不拿 batch-out 的 txt 当唯一凭据**: 非纯简谱/织体/超高的目录**永远不会**产生 txt,
只看 txt 就永远认不出"这个已经看过了" —— 那正是坑 1。

判据(与 `transcribe_source.py` 的幂等键**同源**, 不另立口径):
  * 一个"谱" = `images-prep/<源目录>/<曲名>__<站>-<id>` 这一层子目录;
  * "有图" = 一层内至少一张扩展名匹配且**字节 > 0** 的图;
  * "已转写" = `batch-out/<safe_name(目录名)>.txt` 存在(`safe_name` 直接 import
    `batch_transcribe.safe_name`, 保证与转写侧一字不差)。

输出(**机器可读**, 看门狗按前缀抓):
    PICK=<源目录名>
    LIST=<名单文件绝对路径>
    N=<本轮交出去几个>
退出码 4 = 清单里没有还有未交付目录的源了。

用法:
    py -3.13 tools/transcribe_backlog_pick.py --limit 60
    py -3.13 tools/transcribe_backlog_pick.py --commit --src jianpucn-pop --done-only
"""
import argparse
import io
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
IMG = (".jpg", ".jpeg", ".png", ".gif", ".webp")
EXIT_EMPTY = 4                              # 专用退出码: 清单吃干净了(与"出错"区分开)
DEFAULT_ORDER = os.path.join(ROOT, "train-work", "transcribe_backlog_order.txt")
DEFAULT_STATE = os.path.join(ROOT, "train-work", "transcribe_examined.txt")
DEFAULT_LIST = os.path.join(ROOT, "train-work", "transcribe_round_list.txt")


def has_image(d):
    """一层内至少一张字节 > 0 的图。"""
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


def song_dirs(src):
    """`src` 里有图的谱目录名(排序)。目录不存在返回 None。"""
    r = song_dirs_paged(src)
    return None if r is None else [n for n, _p in r]


def song_dirs_paged(src):
    """`src` 里有图的谱目录 -> [(名字, 图数)]。目录不存在返回 None。

    为什么要图数(**2026-10-08 实测**): 站内原来按**字母序**消费, 于是"这个站的过门率"
    其实测的是"字母序开头那一段的过门率" —— `jp114-14`/`jp114-1` 早期报出的 9.2% 就是这么来的
    假象(已证伪)。按 `_analysis/transcribe_pagecost.py` 的**干净轮实测**分桶(jianpujia-shard):

        图数     处理    产物    过门率    中位秒
        1 张     1776    1640    92.3%     17.0
        5-8 张    242     121    50.0%     21.0

    图多 = **又慢又容易是织体**(多图目录多为钢琴织体/多页改编)。所以站内改成
    **图数升序(单图优先)**, 把字母序这个隐含口径去掉。与 `tools/transcribe_backlog_rank.py`
    的预期产出模型用的是同一个排序键。
    """
    d = os.path.join(PREP, src)
    if not os.path.isdir(d):
        return None
    out = []
    try:
        names = os.listdir(d)
    except OSError:
        return []
    for name in names:
        full = os.path.join(d, name)
        if not os.path.isdir(full):
            continue
        n = 0
        try:
            for f in os.listdir(full):
                if not f.lower().endswith(IMG):
                    continue
                try:
                    if os.path.getsize(os.path.join(full, f)) > 0:
                        n += 1
                except OSError:
                    pass
        except OSError:
            continue
        if n:
            out.append((name, n))
    return sorted(out, key=lambda t: (t[1], t[0]))


def is_done(name):
    return os.path.exists(os.path.join(OUT, safe_name(name) + ".txt"))


def load_state(path):
    """已交付集合。文件不在/读不动就当空的 —— 记账工具不该变成流水线的新单点故障。"""
    seen = set()
    if not os.path.isfile(path):
        return seen
    try:
        with io.open(path, encoding="utf-8", errors="replace") as f:
            for ln in f:
                ln = ln.rstrip("\n")
                if not ln or ln.startswith("#"):
                    continue
                parts = ln.split("\t")
                if len(parts) == 2:
                    seen.add((parts[0], parts[1]))
    except OSError:
        pass
    return seen


def read_order(path, fallback):
    """读清单 -> [(源, 元信息 dict)]。

    清单自 2026-10-08 起由 `tools/transcribe_backlog_rank.py --write` 生成, 每行是**制表符分隔**的
    `<源目录>\t<预期产物/小时>\t<过门率>\t<秒/首>\t<样本量>\t<可信度>\t<出处>` ——
    后 6 列就是"为什么排这里", 人读用; 本函数**只取第 1 列**当源名。
    这样也天然兼容旧的"一行一个源名"格式(没有 tab 时第 1 列就是整行)。
    以 `#` 开头的行是注释。
    """
    if not os.path.isfile(path):
        print("[pick] ⚠ 清单不存在 %s -> 用内置顺序 %d 个" % (path, len(fallback)))
        return [(s, {}) for s in fallback]
    out = []
    with io.open(path, encoding="utf-8") as f:
        for ln in f:
            ln = ln.rstrip("\n")
            if not ln.strip() or ln.lstrip().startswith("#"):
                continue
            parts = ln.split("\t")
            src = parts[0].strip()
            if not src:
                continue
            meta = {}
            if len(parts) >= 5:
                try:
                    meta = dict(per_hour=float(parts[1]), rate=float(parts[2]),
                                sec=float(parts[3]), n_sample=int(parts[4]),
                                conf=parts[5] if len(parts) > 5 else "",
                                why=parts[6] if len(parts) > 6 else "")
                except ValueError:
                    meta = {}
            out.append((src, meta))
    return out


# 站级"测过没有"的门槛(样本量)。低于它就认为这个源的过门率还是先验, 值得用"探针轮"去实测。
MIN_SAMPLE = 200
# 探针游标(一次一个整数, 记"已挑过多少轮")。文件不在/读不动就当 0 —— 记账绝不该变成新的单点故障。
CURSOR = os.path.join(ROOT, "train-work", "transcribe_pick_cursor.txt")


def bump_cursor():
    """轮次游标 +1, 返回**本次**的轮次号(从 1 开始)。"""
    n = 0
    try:
        if os.path.isfile(CURSOR):
            n = int((io.open(CURSOR, encoding="utf-8").read() or "0").strip() or 0)
    except (OSError, ValueError):
        n = 0
    n += 1
    try:
        os.makedirs(os.path.dirname(CURSOR), exist_ok=True)
        io.open(CURSOR, "w", encoding="utf-8", newline="\n").write("%d\n" % n)
    except OSError:
        pass
    return n


# 内置兜底顺序(按 2026-10-06 的积压普查: 真新曲数从多到少)。
# 清单文件在就用清单 —— 这个常量只是"清单丢了也别停摆"。
FALLBACK = ["jianpucn-pop", "jianpujia-shard", "fysongs-all"]


def do_commit(a):
    """把这轮名单里的名字记进状态文件。"""
    if not os.path.isfile(a.list):
        print("[pick] commit: 名单文件不存在 %s" % a.list)
        return 1
    names = []
    with io.open(a.list, encoding="utf-8") as f:
        for ln in f:
            s = ln.strip()
            # ⚠ **不能**按 `#` 当注释跳过: 谱目录名真的有以 `#` 开头的
            #   (实测 `#c小调圆舞曲__jianpucn-101553`), 而 `transcribe_source.py` 的名单模式
            #   只跳过空行、认所有 `#` 开头的行 —— 这里跟着它的口径走, 否则这些目录会被
            #   反复重新交付、永远进不了"已交付"。
            if s:
                names.append(s)
    seen = load_state(a.state)
    added = skipped = 0
    lines = []
    for n in names:
        if a.done_only and not is_done(n):
            skipped += 1                    # 非零退出时只认"真有产物"的, 其余留给下一轮重交
            continue
        if (a.src, n) in seen:
            continue
        lines.append("%s\t%s" % (a.src, n))
        added += 1
    if lines:
        os.makedirs(os.path.dirname(os.path.abspath(a.state)), exist_ok=True)
        with io.open(a.state, "a", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
    print("[pick] commit: %s -> 新记 %d 条 · 因无产物跳过 %d 条 · 状态共 %d 条"
          % (a.src, added, skipped, len(seen) + added))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--order", default=DEFAULT_ORDER)
    ap.add_argument("--state", default=DEFAULT_STATE)
    ap.add_argument("--list", default=DEFAULT_LIST)
    ap.add_argument("--limit", type=int, default=60, help="本轮从选中的源里取几个目录")
    ap.add_argument("--commit", action="store_true", help="把 --list 里的名字记进 --state")
    ap.add_argument("--src", default="", help="配合 --commit: 这批名字属于哪个源")
    ap.add_argument("--done-only", action="store_true", help="配合 --commit: 只记已有产物的")
    ap.add_argument("--explore-every", type=int, default=12,
                    help="每多少轮插一个**探针轮**(去实测还没测过的源); 0=关")
    ap.add_argument("--explore-n", type=int, default=25,
                    help="探针轮最多交出去几个目录(要小, 别拿大块 GPU 时间买先验)")
    ap.add_argument("--explore-scan", type=int, default=15,
                    help="探针轮最多普查几个源就放弃(找「没测过的源」可能要多看几个; 有硬上限防慢)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    if a.commit:
        return do_commit(a)

    order = read_order(a.order, FALLBACK)
    seen = load_state(a.state)
    round_no = bump_cursor()
    explore = bool(a.explore_every) and (round_no % a.explore_every == 0)
    print("[pick] 清单 %d 个源 · 已交付记账 %d 条 · 本轮每个源最多取 %d 个 · 第 %d 轮%s"
          % (len(order), len(seen), a.limit, round_no,
             "(**探针轮**: 去实测还没测过的源)" if explore else ""))

    # 为什么要有探针轮(排序的**自证**机制, 2026-10-08): 严格按产出/小时排 -> 排名靠后的源
    # **永远得不到实测机会**, 它的先验就永远刷不新 —— 一个被旧抽样冤枉的站会被永久压在底下
    # (jp114 那 9.2% 的假象正是这么来的)。所以每 `--explore-every` 轮拿**很小**的一批
    # (`--explore-n`, 默认 25 个 ≈ 8 分钟)去实测一个 `样本量 < MIN_SAMPLE` 的源, 把它的先验换成实测。
    # 代价可控(≈ 5% 的 GPU 时间), 收益是排序不会锁死在旧结论上。
    #
    # 扫描预算(**性能**): 正常轮在"第一个还有货的源"就 `break`(清单已排序, 不用普查全表);
    # 探针轮要多看几个才找得到"没测过的源", 但 `song_dirs_paged` 在 jianpujia-shard 这种
    # 14 万个子目录的源上很贵, 所以给探针轮一个**硬扫描上限**, 超了就退回正常口径。
    cands = []                     # [(序号, 源, fresh, meta)]
    scan_cap = a.explore_scan if explore else 1
    for i, (src, meta) in enumerate(order, 1):
        if len(cands) >= scan_cap:
            break
        dirs = song_dirs_paged(src)
        if dirs is None:
            print("[pick]   %2d. %-24s 目录不存在, 跳过" % (i, src))
            continue
        left = [(n, p) for n, p in dirs if not is_done(n)]
        fresh = [(n, p) for n, p in left if (src, n) not in seen]
        n_smp = meta.get("n_sample")
        print("[pick]   %2d. %-24s 有图 %6d · 未转写 %6d · 其中未交付 %6d · %s"
              % (i, src, len(dirs), len(left), len(fresh),
                 ("样本 %d" % n_smp) if n_smp is not None else "(旧格式, 无样本量)"))
        if not fresh:
            continue
        cands.append((i, src, fresh, meta))
        if not explore:
            break                                  # 正常轮: 第一个有货的源就是它
        if n_smp is None or n_smp < MIN_SAMPLE:
            break                                  # 探针轮: 找到"还没测过"的就停

    if not cands:
        print("[pick] 清单里没有还有未交付目录的源 —— 积压已清空(或全部已交付)")
        print("PICK=")
        print("N=0")
        return EXIT_EMPTY

    # 探针轮: 若扫到的最后一个确实是"样本量不足", 就走探针口径; 否则退回正常口径(第一个有货的源)。
    i, src, fresh, meta = cands[-1]
    n_smp = meta.get("n_sample")
    is_probe = bool(explore and len(cands) > 1 and (n_smp is None or n_smp < MIN_SAMPLE))
    if is_probe:
        cap = min(a.limit, a.explore_n)
    else:
        i, src, fresh, meta = cands[0]
        cap = a.limit
    # 站内**: 图数升序**(单图优先) —— `song_dirs_paged` 已经按 (图数, 名字) 排好, 取前 cap 个。
    take = [n for n, _p in fresh[:cap]]
    mix = {}
    for _n, p in fresh[:cap]:
        b = "1" if p <= 1 else ("2" if p == 2 else ("3-4" if p <= 4 else ("5-8" if p <= 8 else ">8")))
        mix[b] = mix.get(b, 0) + 1
    os.makedirs(os.path.dirname(os.path.abspath(a.list)), exist_ok=True)
    with io.open(a.list, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(take) + "\n")
    print("[pick]   本轮交出去 %d 个%s · 图数构成 %s -> %s"
          % (len(take), "(**探针轮**)" if is_probe else "",
             " ".join("%s张:%d" % (k, v) for k, v in sorted(mix.items())), a.list))
    print("PICK=%s" % src)
    print("LIST=%s" % os.path.abspath(a.list))
    print("N=%d" % len(take))
    return 0


if __name__ == "__main__":
    sys.exit(main())
