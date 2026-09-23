#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把"旋律短到不可能被检索"的曲谱移出 scores/(隔离, 不删) —— 修 OCR 失败留下的垃圾。

为什么: 检索最少要求 5 个音(锦囊 §2/§5), 所以**旋律音 < 5 的曲永远不可能被查到**。
实测有 14 首是**转写失败**的产物: 整份谱几乎全是休止 `0`/念白 `x`/延长 `-`,
只剩 1~3 个真音(例: `屋顶` = `- - - x hx dx x 1 x' x x' x` 只有 1 个音;
`芭蕉布` = `1 - - - - - - …`)。它们对检索毫无贡献, 却混在 data.jsonl / HF 数据集里。

做法: **移动**到 `scores-suspect/`(照 batch-out-bad 的先例, 只移不删), 原始转写证据仍在;
之后跑 parse_scores.py 它们自然就不在 data.jsonl 里了。可逆: 把文件移回 scores/ 即可。

用法:
  python3 jianpu2/tools/quarantine_short_scores.py            # 只看会移哪些(--dry)
  python3 jianpu2/tools/quarantine_short_scores.py --apply
  python3 jianpu2/tools/quarantine_short_scores.py --min 8 --apply   # 换阈值
"""
import argparse
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
DEST = os.path.join(DB, "scores-suspect")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402
sys.stdout.reconfigure(encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min", type=int, default=5, help="旋律音少于这个数就隔离(默认 5, 与检索下限一致)")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    rows = [json.loads(l) for l in open(os.path.join(DB, "data.jsonl"), encoding="utf-8")]
    hits = []
    for r in rows:
        n = len(jptok.seq(r.get("score") or ""))
        if n < a.min:
            hits.append((n, (r.get("file") or [""])[0], r.get("title") or "", (r.get("source") or [""])[0]))
    hits.sort()
    print("旋律音 < %d 的曲: %d 首" % (a.min, len(hits)))
    for n, fn, title, src in hits:
        print("   %2d 音  %-34s %-18s %s" % (n, fn[:34], title[:18], src))
    if not a.apply:
        print("\n(--apply 才会真的移走; 现在只是预览)")
        return 0
    os.makedirs(DEST, exist_ok=True)
    moved = 0
    for n, fn, title, src in hits:
        for suffix in ("", "_expand", "_buf"):
            for ext in (".txt", ".json"):
                p = os.path.join(SCORES, fn[:-4] + suffix + ext)
                if os.path.isfile(p):
                    shutil.move(p, os.path.join(DEST, os.path.basename(p)))
        moved += 1
    with open(os.path.join(DEST, "README.md"), "w", encoding="utf-8", newline="\n") as g:
        g.write("# scores-suspect —— 被隔离的曲谱(只移不删)\n\n"
                "`%s` 由 `jianpu2/tools/quarantine_short_scores.py` 移入: **旋律音 < %d 个**,\n"
                "而检索下限就是 5 个音 —— 这些曲永远不可能被查到, 且实测几乎都是\n"
                "转写失败的产物(整份谱只剩休止/念白/延长, 真音 1~3 个)。\n\n"
                "要恢复: 把文件移回 `../scores/` 再跑 `python3 parse_scores.py`。\n"
                % (__import__("time").strftime("%Y-%m-%d %H:%M"), a.min))
    print("\n已隔离 %d 首 -> %s" % (moved, DEST))
    print("记得跑 parse_scores.py 重建索引。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
