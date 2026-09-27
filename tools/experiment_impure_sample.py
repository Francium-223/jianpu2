# -*- coding: utf-8 -*-
"""取样实验: 被"纯简谱门"挡下的改编/器乐谱, 转写出来到底能不能用?

背景: `transcribe_source.py` 是**先转写、再按纯度门丢掉**(被挡的连 png 都删)。
所以"要不要放宽口径"这个决定, 缺的只是**看一眼那些被丢掉的结果**。
本脚本不碰语料、不改纯度门、不动流水线的输出 —— 只把指定的 N 个目录转写结果
落到 `train-work/impure_sample/`, 并打印每份的 token/数字统计, 供人眼判断 3 份即可。

用法(★ 要等 GPU 空, 现在流水线独占):
    py -3.13 tools/experiment_impure_sample.py                 # 默认抽 30 个(按清单均匀取样)
    py -3.13 tools/experiment_impure_sample.py --n 10
    py -3.13 tools/experiment_impure_sample.py --list ..\\_analysis\\arrangement_candidates.tsv
"""
import argparse
import io
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
os.chdir(ROOT)
import batch_transcribe as BT          # noqa: E402  与流水线同一套转写实现
import jp_transcribe as JP             # noqa: E402  同一套纯度判据

OUT = os.path.join("train-work", "impure_sample")


def spread(items, n):
    """按清单**均匀取样**, 不要只取开头 —— 清单是按曲名排序的, 前 N 个可能全是同一批站。"""
    if n <= 0 or n >= len(items):
        return list(items)
    step = len(items) / float(n)
    return [items[int(i * step)] for i in range(n)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", default=os.path.join(os.path.dirname(ROOT), "_analysis",
                                                   "arrangement_candidates.tsv"))
    ap.add_argument("--n", type=int, default=30)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    if not os.path.isfile(a.list):
        sys.exit("找不到清单: %s(先跑 audit_arrangements.py)" % a.list)
    rows = [l.rstrip("\n").split("\t") for l in io.open(a.list, encoding="utf-8") if l.strip()]
    hdr, body = rows[0], rows[1:]
    ipath = hdr.index("path_in_images_prep") if "path_in_images_prep" in hdr else 1
    raw = [r[ipath] for r in body if len(r) > ipath and r[ipath]]
    # 清单里的路径是**相对工作区**写的(如 `jianpu2/images-prep/<站点-歌手>/<曲名>__<id>`),
    # 而本脚本的 cwd 是 jianpu2 —— 只按 cwd 解析会一个都找不到(实测清单 1859 条 -> 命中 0)。
    # 所以依次试: 工作区相对 / jianpu2 相对 / 绝对。
    WS = os.path.dirname(ROOT)
    dirs = []
    for p in raw:
        for cand in (os.path.join(WS, p), os.path.join(ROOT, p), p):
            if os.path.isdir(cand):
                dirs.append(cand)
                break
    if not dirs:
        sys.exit("清单里的目录一个都不存在 —— 路径基准不对? 样例: %s" % (raw[0] if raw else "(空)"))
    pick = spread(dirs, a.n)
    print("清单 %d 个目录 -> 取样 %d 个(均匀取样, 不是前 N 个)" % (len(dirs), len(pick)))
    os.makedirs(a.out, exist_ok=True)

    ok = blocked = empty = 0
    for i, d in enumerate(pick):
        page = BT.pick_page(d)
        if not page:
            print("[%d/%d] %s: 没有可用页" % (i + 1, len(pick), os.path.basename(d)[:40]))
            continue
        name = BT.safe_name(os.path.basename(d))
        txt = os.path.join(a.out, name + ".txt")
        png = os.path.join(a.out, name + ".png")
        if os.path.exists(txt):
            continue
        t0 = time.time()
        try:
            impure = JP.is_impure(page)
            toks, _meta = BT.transcribe_paged(page, txt, png)
        except Exception as ex:                                 # noqa: BLE001
            print("[%d/%d] %s: 失败 %s" % (i + 1, len(pick), name[:40], type(ex).__name__))
            continue
        digs = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.")
                   and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        # 关键区别: **不管纯不纯都留下**(这正是流水线会丢掉的部分)
        with io.open(txt, "w", encoding="utf-8") as f:
            f.write(" ".join(toks))
        blocked += 1 if impure else 0
        empty += 1 if digs == 0 else 0
        ok += 1 if digs else 0
        print("[%d/%d] %s: token %d 数字 %d  纯度门=%s  (%.0fs)"
              % (i + 1, len(pick), name[:40], len(toks), digs,
                 "挡住" if impure else "放行", time.time() - t0), flush=True)

    print("\n=== 小结 ===")
    print("  转出 %d 份; 其中纯度门本来会挡掉的 %d 份; 有音符的 %d 份; 0 音符的 %d 份"
          % (len(pick), blocked, ok, empty))
    print("  结果在 %s —— **人眼看 3 份**(尤其纯度门挡住又有音符的那些):" % a.out)
    print("    能用的比例高 -> 值得放宽口径(清单见 _analysis/arrangement_candidates.tsv)")
    print("    基本是垃圾   -> 维持现状, 这批不进语料")
    return 0


if __name__ == "__main__":
    sys.exit(main())
