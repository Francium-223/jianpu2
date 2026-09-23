# -*- coding: utf-8 -*-
"""核对"定向爬来的曲谱"是不是**我们要的那首歌**、以及**能不能转写**。

背景: `crawl_missing_mandopop.py` -> `crawl_qupu123.py` 是**按关键词搜索**下载的,
搜索是模糊的 —— 实测「前尘」下回来《前尘如梦》《前尘旧梦不再提》,「虚拟」下回来
《虚拟的女孩》《虚拟的男孩》(都不是那首歌)。不核对就往转写队列里塞 = 往语料里
灌错误歌曲。所以每轮定向爬完都过一遍这个脚本。

它做两件事:
  1. **认歌**: 下载目录名里的页面标题 vs 目标曲名(用 eval 的 norm/same 同一份口径);
  2. **认类型**: 从标题后缀判是不是"能转成简谱旋律"的谱 —— 吉他谱/钢琴谱/古筝谱/
     竹笛谱/口琴谱/乐队总谱/正谱/编配 这类**器乐改编**按项目口径(锦囊 §8-5)不收。

用法:
    python3 tools/verify_crawl_matches.py --list train-work/mandopop_missing_new_20260924.txt
    python3 tools/verify_crawl_matches.py --list <清单> --out _analysis/转写队列.tsv
"""
import argparse
import difflib
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SKILL = os.path.join(ROOT, "skills", "jianpu-melody-lookup")
if SKILL not in sys.path:
    sys.path.insert(0, SKILL)
from eval_golden import norm, same          # noqa: E402  同一份曲名口径

# 器乐/改编类后缀(项目口径: 这些转不出"那首歌的旋律", 锦囊 §8-5)
ARRANGE = re.compile(r"吉他|钢琴|古筝|竹笛|口琴|琵琶|二胡|小提琴|长笛|萨克斯|尤克里里|"
                     r"乐队|总谱|正谱|编配|弹唱|和弦|指弹|独奏|伴奏|练习曲|考级|重奏|合奏|"
                     r"五线谱|简和谱|卡林巴|电子琴|双排键")


def load_targets(paths):
    """要爬的清单(slug -> 目标曲名), slug 来自 crawl 日志。"""
    want = {}
    for path in paths:
        for ln in io.open(path, encoding="utf-8"):
            if not ln.strip():
                continue
            c = ln.rstrip("\n").split("\t")
            if len(c) >= 2:                  # 清单是 `曲名<TAB>歌手`
                want[c[0].strip()] = c[1].strip()
    return want


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=os.path.join(ROOT, "train-work", "mandopop_crawl.tsv"))
    ap.add_argument("--img", default=os.path.join(ROOT, "images-prep"))
    ap.add_argument("--list", nargs="*", default=[], help="要核对的目标清单(歌名<TAB>歌手)")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    targets = load_targets(a.list)
    # 日志: 歌名 -> slug。**同一首可能有多轮**(首轮 + --redo), 而且两轮的 slug 会重号
    # (`mp001` 在旧爬里是《未来的主人翁》、在新爬里是《万里长城永不倒》) —— 所以要
    # 逐个 slug 看目录**存不存在**, 取第一个真存在的(2026-09-24 修: 之前只取最后一个,
    # 拿旧图目录配新日志, 结果整批判成"不同歌")。
    slug, all_slugs = {}, {}
    for ln in io.open(a.log, encoding="utf-8"):
        c = ln.rstrip("\n").split("\t")
        if len(c) >= 4 and c[0]:
            all_slugs.setdefault(c[0], []).append(c[3])
    for t, slugs in all_slugs.items():
        for s0 in slugs:
            if os.path.isdir(os.path.join(a.img, f"qupu123-{s0}")):
                slug[t] = s0
                break
        else:
            slug[t] = slugs[-1]
    if not targets:
        targets = {t: t for t in slug}

    out = ["目标曲名\t页面标题\t页面id\t判定\t类型\t本地目录"]
    rows, good, plain = [], {}, {}
    for target, _artist in targets.items():
        s = slug.get(target)
        d = os.path.join(a.img, f"qupu123-{s}") if s else ""
        if not d or not os.path.isdir(d):
            continue
        for sub in sorted(os.listdir(d)):
            m = re.match(r"^(.*)__qupu123-(\d+)$", sub)
            if not m:
                continue
            pt, pid = m.group(1), m.group(2)
            hit = same(norm(pt), norm(target))
            ratio = difflib.SequenceMatcher(None, norm(pt), norm(target)).ratio()
            kind = "改编/器乐" if ARRANGE.search(pt) else "简谱(疑似可转写)"
            verdict = "同名✓" if hit else ("疑似" if ratio >= 0.6 else "不同歌✗")
            rows.append((target, pt, pid, verdict, kind, f"qupu123-{s}/{sub}"))
            if hit:
                good.setdefault(target, []).append((pt, pid, kind))
                if kind.startswith("简谱"):
                    plain.setdefault(target, []).append((pt, pid))

    print(f"目标 {len(targets)} 首; 有下载的 {len({r[0] for r in rows})} 首; 目录 {len(rows)} 个")
    print(f"  **同名**(就是这首歌)的目录 {sum(1 for r in rows if r[3]=='同名✓')} 个, "
          f"疑似 {sum(1 for r in rows if r[3]=='疑似')} 个, 不同歌 {sum(1 for r in rows if r[3]=='不同歌✗')} 个")
    print(f"  有同名谱的**歌** {len(good)} 首; 其中含**非改编(疑似简谱)**的歌 {len(plain)} 首")
    if plain:
        print("\n可直接进转写队列的(歌 <- 页面):")
        for t, v in sorted(plain.items()):
            for pt, pid in v:
                print(f"  {t:14s} <- {pt[:38]:40s} id={pid}")
    wrong = sorted({(r[0], r[1]) for r in rows if r[3] == "不同歌✗"})
    if wrong:
        print(f"\n搜到但不是这首歌的 {len(wrong)} 条(说明搜索是模糊的, 别直接信):")
        for t, pt in wrong[:10]:
            print(f"  「{t}」<- 「{pt}」")
    for r in rows:
        out.append("\t".join(r))
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        io.open(a.out, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
        print(f"\n明细 -> {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
