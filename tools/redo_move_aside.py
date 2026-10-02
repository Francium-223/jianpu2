# -*- coding: utf-8 -*-
"""**重做前的准备**：把名单里那些"已有转写"的产物移到 `batch-out/_superseded/`，好让转写器重新做一遍。

## 为什么需要它（我踩过的坑）
`batch_transcribe.py` 是**断点续传**：输出 `.txt` 已存在就 `continue`（第 207 行附近），**没有 `--force`**。
所以我第一次"重转 15 份碎片谱"时，它打印了 `完成 14/17` 看着像成功，
实际上**对真正需要重做的那些（已有旧转写的）什么都没干** —— 又是一次"静默成功"。
正确做法：先把旧产物**移开**（不是删，见下），再跑转写，它就真的重做了。

## 只移不删
移到 `batch-out/_superseded/`（保留原文件名 + 时间戳），并写一份 `manifest.tsv`：
`名字 / 旧产物路径 / 旧音符数 / 移动时间`。移开的东西**一个都没删**，随时可以移回来对比。

用法:
    py -3.13 tools/redo_move_aside.py --list train-work/redo_fragments_v1.txt            # 只看会动什么(默认)
    py -3.13 tools/redo_move_aside.py --list train-work/redo_fragments_v1.txt --apply    # 真移
"""
from __future__ import annotations

import argparse
import glob
import io
import os
import re
import shutil
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "batch-out")
SUP = os.path.join(OUT, "_superseded")


def notes_of(txt):
    """粗算音符数：正整数个数（与抽检口径一致，只为对比，不当精确值）。"""
    try:
        return len(re.findall(r"[1-7]", io.open(txt, encoding="utf-8", errors="replace").read()))
    except OSError:
        return -1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", required=True, help="重转名单（每行一个目录名或曲谱名）")
    ap.add_argument("--apply", action="store_true", help="真移；不给就是 dry-run")
    a = ap.parse_args()

    names = [ln.strip() for ln in io.open(a.list, encoding="utf-8")
             if ln.strip() and not ln.strip().startswith("#")]
    os.makedirs(SUP, exist_ok=True)

    moves, missing = [], []
    for name in names:
        # 名单里可能是"目录名"（<曲名>__<source>）也可能是"曲谱文件名"，两种都按前缀找
        stem = os.path.splitext(name)[0]
        hits = sorted(set(glob.glob(os.path.join(OUT, stem + ".txt"))
                          + glob.glob(os.path.join(OUT, stem + "_p*.txt"))))
        if not hits:
            missing.append(name)
            continue
        for txt in hits:
            base = os.path.splitext(txt)[0]
            group = [txt] + [p for p in (base + ".json", base + ".png",
                                         base + "_p1.png", base + ".txt.json") if os.path.exists(p)]
            moves.append((os.path.basename(base), group, notes_of(txt)))

    total = sum(len(g) for _, g, _ in moves)
    print(f"名单 {len(names)} 条 -> 命中 {len(moves)} 份已有转写（{total} 个文件）"
          + (f"，另有 {len(missing)} 条没有旧转写（会被直接转写）" if missing else ""))
    for b, g, n in moves[:8]:
        print(f"  {b[:56]:<56} 旧音符 {n:>5} · {len(g)} 个文件")
    if len(moves) > 8:
        print(f"  …（共 {len(moves)} 份）")
    if not a.apply:
        print("\n（dry-run，什么都没动；确认无误后加 --apply）")
        return 0

    stamp = time.strftime("%Y%m%d-%H%M%S")
    man = os.path.join(SUP, "manifest.tsv")
    with io.open(man, "a", encoding="utf-8", newline="\n") as f:
        for b, g, n in moves:
            for p in g:
                dst = os.path.join(SUP, os.path.basename(p))
                if os.path.exists(dst):                      # 同名的旧件加时间戳，绝不覆盖
                    dst = os.path.join(SUP, f"{stamp}_{os.path.basename(p)}")
                shutil.move(p, dst)
                f.write(f"{stamp}\t{os.path.basename(p)}\t{dst}\t{n}\n")
    print(f"\n已移开 {total} 个文件 -> {SUP}\n清单: {man}（**没有删除任何东西**）")
    print("下一步: py -3.13 tools/transcribe_source.py " + a.list)
    return 0


if __name__ == "__main__":
    sys.exit(main())
