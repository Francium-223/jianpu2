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
    d = os.path.join(PREP, src)
    if not os.path.isdir(d):
        return None
    out = []
    try:
        names = os.listdir(d)
    except OSError:
        return []
    for name in names:
        if os.path.isdir(os.path.join(d, name)) and has_image(os.path.join(d, name)):
            out.append(name)
    return sorted(out)


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
    if not os.path.isfile(path):
        print("[pick] ⚠ 清单不存在 %s -> 用内置顺序 %d 个" % (path, len(fallback)))
        return list(fallback)
    out = []
    with io.open(path, encoding="utf-8") as f:
        for ln in f:
            s = ln.strip()
            if s and not s.startswith("#"):
                out.append(s)
    return out


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
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    if a.commit:
        return do_commit(a)

    order = read_order(a.order, FALLBACK)
    seen = load_state(a.state)
    print("[pick] 清单 %d 个源 · 已交付记账 %d 条 · 本轮每个源最多取 %d 个" % (len(order), len(seen), a.limit))

    for i, src in enumerate(order, 1):
        dirs = song_dirs(src)
        if dirs is None:
            print("[pick]   %2d. %-24s 目录不存在, 跳过" % (i, src))
            continue
        left = [d for d in dirs if not is_done(d)]
        fresh = [d for d in left if (src, d) not in seen]
        print("[pick]   %2d. %-24s 有图 %6d · 未转写 %6d · 其中未交付 %6d"
              % (i, src, len(dirs), len(left), len(fresh)))
        if not fresh:
            continue
        take = fresh[:a.limit]
        os.makedirs(os.path.dirname(os.path.abspath(a.list)), exist_ok=True)
        with io.open(a.list, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(take) + "\n")
        print("[pick]   本轮交出去 %d 个 -> %s" % (len(take), a.list))
        print("PICK=%s" % src)
        print("LIST=%s" % os.path.abspath(a.list))
        print("N=%d" % len(take))
        return 0

    print("[pick] 清单里没有还有未交付目录的源 —— 积压已清空(或全部已交付)")
    print("PICK=")
    print("N=0")
    return EXIT_EMPTY


if __name__ == "__main__":
    sys.exit(main())
