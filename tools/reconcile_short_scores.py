# -*- coding: utf-8 -*-
"""库里"音数太少、查不到"的谱, 一旦同一份谱有了更完整的转写, 就把短的那份**移**去隔离(不删)。

为什么要单独做: 短谱(`< 11 音`, 检索一段 11 音的旋律永远匹配不到它)是**转写失败**留下的,
但"直接隔离"会把还能救的歌一起弄丢 —— 正确顺序是**先重转**(图都在), 重转进了语料之后,
再回头把那份短的挪走。本工具就是"回头"这一步, 判据宁可保守:

  第 1 档(同一 source id 有了更长的谱): 同一次爬下来的**同一张谱**, 现在有更完整版本 -> 短的那份可以撤。
  第 2 档(同名且旋律确有重叠): 不同来源的同名歌, 新版本包含短谱的那几个音(>= 短谱音数的一半) -> 提出来给人看。
  两档都只是**提案**, 默认 dry; `--apply` 只动第 1 档(第 2 档要人眼, 因为同名不同歌很常见)。

用法:
    py -3.13 tools/reconcile_short_scores.py                  # 只看
    py -3.13 tools/reconcile_short_scores.py --apply          # 移第 1 档
    py -3.13 tools/reconcile_short_scores.py --min 11 --apply
"""
import argparse
import difflib
import glob
import io
import json
import os
import shutil
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫必须是**第一段实际代码**
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
from lookup import pitch_and_oct, group_of      # noqa: E402  与检索同一口径
from eval_golden import norm                    # noqa: E402  曲名口径复用同一份


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--scores", default=os.path.join(DB, "scores"))
    ap.add_argument("--dest", default=os.path.join(DB, "scores-suspect"))
    ap.add_argument("--min", type=int, default=11, help="少于这么多音算'短'(默认 11 = 常用查询长度)")
    ap.add_argument("--overlap", type=float, default=0.5, help="第 2 档要求短谱旋律有多少比例出现在长谱里")
    ap.add_argument("--apply", action="store_true", help="只移第 1 档(同一 source 有更长版本)")
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    info = []
    for r in rows:
        p, _o = pitch_and_oct(r.get("score") or "")
        f = r.get("file") or [""]
        f = f[0] if isinstance(f, list) else f
        src = r.get("source") or ""
        src = src[0] if isinstance(src, list) else src
        info.append({"n": len(p), "p": p, "file": f, "src": src,
                     "group": norm(group_of(r.get("title") or "")), "title": r.get("title")})
    shorts = [x for x in info if 0 < x["n"] < a.min]
    longs = [x for x in info if x["n"] >= a.min]
    print(f"语料 {len(info)} 首 · 短谱(<{a.min} 音) {len(shorts)} 首 · 长谱 {len(longs)} 首")

    by_src = {}
    for x in longs:
        if x["src"]:
            by_src.setdefault(x["src"], []).append(x)
    tier1, tier2 = [], []
    for s in shorts:
        cand = by_src.get(s["src"]) if s["src"] else None
        if cand:
            best = max(cand, key=lambda y: y["n"])
            tier1.append((s, best))
            continue
        # 第 2 档: 同名 + 旋律有重叠
        for y in longs:
            if y["group"] and y["group"] == s["group"] and s["p"]:
                blk = difflib.SequenceMatcher(None, s["p"], y["p"], autojunk=False).find_longest_match(
                    0, len(s["p"]), 0, len(y["p"])).size
                if blk >= max(3, int(len(s["p"]) * a.overlap)):
                    tier2.append((s, y, blk))
                    break

    print()
    print(f"### 第 1 档(同一 source 已有更长的谱, 短的那份可撤): {len(tier1)} 首")
    for s, b in tier1:
        print(f"   {s['n']:>2} 音 -> {b['n']:>3} 音  {str(s['title'])[:20]:<22} src={s['src']:<18} "
              f"{s['file'][:28]}  (新的: {b['file'][:28]})")
    print()
    print(f"### 第 2 档(同名且旋律重叠, 要人眼): {len(tier2)} 首")
    for s, y, blk in tier2:
        print(f"   {s['n']:>2} 音 (重合 {blk}) vs {y['n']:>3} 音  {str(s['title'])[:20]:<22} "
              f"{s['src']:<18} {s['file'][:26]} / {y['src']}")

    if not a.apply:
        print("\n(dry) 加 --apply 才会把第 1 档移去隔离。")
        return
    os.makedirs(a.dest, exist_ok=True)
    moved = 0
    for s, _b in tier1:
        src_p = os.path.join(a.scores, s["file"])
        if not os.path.isfile(src_p):
            print(f"   !! 找不到 {src_p}")
            continue
        dst_p = os.path.join(a.dest, s["file"])
        if os.path.exists(dst_p):
            print(f"   跳过(隔离目录里已有): {s['file']}")
            continue
        shutil.move(src_p, dst_p)
        moved += 1
    print(f"\n已移 {moved} 份 -> {a.dest}  (只移不删; 可逆: 移回 scores/ 即可)")
    print("下一步: cd %s && py parse_scores.py   (重建 data.jsonl)" % DB)


if __name__ == "__main__":
    main()
