# -*- coding: utf-8 -*-
"""从"图库里还没转录过的目录"里取下一批(切片), 交给 transcribe_source.py。

背景(2026-09-29 实测): 图库 20,689 个谱图目录, 只有 11,305 个有转录稿(batch-out/*.txt),
**9,384 个从没试过** —— 其中 jianpucn 6,752 / qupu123 1,571 / jianpujia 1,056 / user 4。
plan_next_batch.py 只在 12 个固定源里各取 60 个(总共 720), 对这么大的欠账太窄;
本工具按**源优先级**切整片欠账, 并且**每批都留出统计**(转录后能算这一源的实测命中率,
不再靠"按名字猜纯度"——那个方法实测 87% 预测 vs ~1% 真实)。

优先级理由: jianpujia / user 多为整页简谱; jianpucn 简谱多但混吉他谱; qupu123 多为双谱(命中率最低)。

用法:
  py -3.13 tools/next_backlog_slice.py [个数=400] [--out 文件] [--src jianpujia,jianpucn]
输出: train-work/backlog_slice.txt(每行一个图库目录名), 控制台打印各源构成。
"""
import argparse
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

ROOT = r"D:\Documents_D\jianpu2"
IMG_ROOTS = [os.path.join(ROOT, "images-prep"), os.path.join(ROOT, "images")]
BOUT = os.path.join(ROOT, "batch-out")
PRIORITY = ["user", "jianpujia", "qupu123", "jp114", "jianpucn"]

# **按名字挡掉"非旋律谱"**(2026-09-30 加, 用户 09-29 晚点头的那一档)。实测依据:
#   图库 28,863 个目录里, 名字带 贝斯/鼓谱/架子鼓/打击乐/吉他/指弹/弹唱/六线 的有 **1,217 个**,
#   已转过的 67 个里 —— 音符数中位 **320**(全库中位 222)、**平均含念白 `x` 26.1 个**、
#   最长 **3,558** 个 token; 而"token > 1000"的占 **5/67 (7.5%)**, 全库只有 37/8827 (0.4%),
#   超代表 17 倍。这些东西是贝斯谱/鼓谱/六线谱 —— 数字长得像简谱, 进了旋律语料就是噪声。
#   (钢琴**不在这张名单里**: 钢琴谱里有真旋律, 改由 jp_transcribe 的"织体页"判据按内容挡。)
#   `--allow-junk` 可以放行(想复核时用); 名单本身也可用 `--skip` 覆盖。
JUNK_NAME = re.compile(r"贝斯|鼓谱|架子鼓|打击乐|六线|指弹谱|吉他谱")


def source_of(name):
    m = re.search(r"__([A-Za-z0-9_]+)", name)
    return (m.group(1) if m else "?").lower()


def library_dirs():
    out = []
    for root in IMG_ROOTS:
        if not os.path.isdir(root):
            continue
        for d in sorted(os.listdir(root)):
            p = os.path.join(root, d)
            if not os.path.isdir(p):
                continue
            if "__" in d:
                out.append(d)
                continue
            for e in sorted(os.listdir(p)):
                if os.path.isdir(os.path.join(p, e)) and "__" in e:
                    out.append(e)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("count", nargs="?", type=int, default=400)
    ap.add_argument("--out", default=os.path.join(ROOT, "train-work", "backlog_slice.txt"))
    ap.add_argument("--src", default="", help="只看这些源(逗号分隔), 默认按 PRIORITY 全要")
    ap.add_argument("--skip", default=JUNK_NAME.pattern, help="名字里带这些词就跳过(正则), 默认挡非旋律谱")
    ap.add_argument("--allow-junk", action="store_true", help="放行非旋律谱(贝斯/鼓/六线等), 复核时用")
    a = ap.parse_args()

    have = {os.path.splitext(f)[0] for f in os.listdir(BOUT) if f.endswith(".txt")}
    all_dirs = library_dirs()
    fresh = [d for d in all_dirs if d not in have]
    skipped = []
    if not a.allow_junk and a.skip:
        rx = re.compile(a.skip)
        kept = []
        for d in fresh:
            (skipped if rx.search(d) else kept).append(d)
        fresh = kept
        print(f"按名字跳过非旋律谱(贝斯/鼓/六线…): {len(skipped)} 个"
              f"（--allow-junk 可放行; 名单: {a.skip}）")
    want = [s.strip().lower() for s in a.src.split(",") if s.strip()]
    order = want if want else PRIORITY
    buckets = collections.defaultdict(list)
    for d in fresh:
        buckets[source_of(d)].append(d)

    picked, taken = [], collections.Counter()
    for s in order:
        for d in buckets.pop(s, []):
            if len(picked) >= a.count:
                break
            picked.append(d)
            taken[s] += 1
        if len(picked) >= a.count:
            break
    if len(picked) < a.count:                      # 还不够就拿剩下的源
        for s in sorted(buckets):
            for d in buckets[s]:
                if len(picked) >= a.count:
                    break
                picked.append(d)
                taken[s] += 1
            if len(picked) >= a.count:
                break

    with open(a.out, "w", encoding="utf-8") as f:
        for d in picked:
            f.write(d + "\n")
    print(f"图库 {len(all_dirs)} 个 · 已有转录稿 {len(all_dirs) - len(fresh)} · 欠账 {len(fresh)}")
    print(f"本批 {len(picked)} 个 -> {a.out}")
    for s, n in taken.most_common():
        print(f"   {s:<12}{n:>6}  (该源总欠账 {len(buckets.get(s, [])) + n})")


if __name__ == "__main__":
    main()
