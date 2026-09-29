# -*- coding: utf-8 -*-
"""（**已降级为草稿工具**，留在 _analysis 里备查：实测这个判据分辨力很低 —— 89.6% 的 11 音窗口
在全库本来就是独证，因为每首歌本来就各不相同；真正有分辨力的是"同一首歌的别的版本"，
见 `tools/qa_version_outliers.py`。）

独证自检：找出**只有一份谱能佐证**的长片段 —— 这类片段是 OCR 误读最容易蒙混过关的地方。

为什么需要它（2026-09-29 实测的教训）：
  前端曾出现"同一条 11 音查询，离线排《神々》、前端排《你怎么说》"，查下去发现《你怎么说》那条
  语料**本身就是误读**（转写把"行尾的 `3 -`"和紧跟的"间奏括号 `(5 6 | 5 6 5 3 2`"连读成了
  `33565653253`，还丢了几个音）。这种假片段有个共同特征：**库里只有它一处**，
  没有"同一首歌的别的版本/别的谱"来交叉核对 —— 也就是**独证**。

本工具把这件事量出来（只读，不改任何数据）：
  * 把每首谱的音高串（唯一口径 jptok/lookup）切成 W 音的窗口，统计每个窗口出现在**几首不同的歌**里；
  * `只在一首歌里出现`的窗口就是独证窗口；再按"这处上下文像不像拼接现场"分档：
      - 邻域里 `x`（念白/被读成念白的词）或 `-`（延长）多 -> 更像"行尾/括号交界被连读"；
      - 该谱 status=ocr -> 机器转写，没有人工兜底。
  * 输出 TSV（片段/窗口数/歌名/文件/上下文/标记），并打印统计与最可疑的若干条。

用法: py -3.13 tools/qa_single_witness.py [--w 11] [--top 40] [--out 报告.tsv]
"""
import argparse
import collections
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

ROOT = r"D:\Documents_D\jianpu2"
DB = r"D:\Documents_D\jianpu-db"
SKILL = os.path.join(ROOT, "skills", "jianpu-melody-lookup")
sys.path.insert(0, SKILL)
from lookup import pitch_and_oct     # noqa: E402  与检索同源的音高口径


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--w", type=int, default=11, help="窗口长度(音)")
    ap.add_argument("--top", type=int, default=40, help="打印多少条最可疑的")
    ap.add_argument("--out", default=os.path.join(ROOT, "train-work", "single_witness.tsv"))
    a = ap.parse_args()

    W = a.w
    songs = []          # (title, file, status, pitches, tokens)
    for line in io.open(a.data, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        sc = d.get("score") or ""
        p, _o = pitch_and_oct(sc)
        if len(p) < W:
            continue
        songs.append((d.get("title") or "", (d.get("file") or [""])[0],
                      (d.get("status") or ""), p, sc))

    where = collections.defaultdict(set)          # 窗口 -> {曲名}
    for t, _f, _s, p, _sc in songs:
        seen = set()
        for i in range(len(p) - W + 1):
            w = p[i:i + W]
            if w not in seen:                      # 同一首里重复出现只算一次
                seen.add(w)
                where[w].add(t)

    single = [w for w, ts in where.items() if len(ts) == 1]
    print(f"语料 {len(songs)} 首 · 窗口长度 {W} · 不同窗口 {len(where):,} · "
          f"**独证窗口**(只在一首歌里出现) {len(single):,} = {len(single)/max(1,len(where))*100:.1f}%")

    rows = []
    for t, f, st, p, sc in songs:
        for i in range(len(p) - W + 1):
            w = p[i:i + W]
            if w not in where or len(where[w]) != 1:
                continue
            ctx = p[max(0, i - 10):i + W + 10]
            # 上下文"像不像拼接现场": 念白 x / 延长 - 多 => 更像行尾/括号交界被连读
            mark = []
            if st == "ocr":
                mark.append("机器转写")
            mx = len(re.findall(r"x", sc))
            if mx:
                mark.append(f"谱内有念白x{mx}")
            dash = len(re.findall(r"(?:^|\s)-(?:\s|$)", sc))
            if dash >= 20:
                mark.append(f"延长-{dash}")
            rows.append((w, t, f, st, ctx, " ".join(mark)))
            break                                   # 每首只报第一处, 免得刷屏

    rows.sort(key=lambda r: (len(r[5]) == 0, r[3] != "ocr", r[1]))
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with io.open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("片段\t曲名\t文件\tstatus\t上下文\t标记\n")
        for r in rows:
            g.write("\t".join(r) + "\n")
    print(f"独证窗口落在 {len(rows)} 首谱里 -> {a.out}")
    print("最可疑的 %d 条(机器转写 + 上下文带念白/延长):" % a.top)
    for w, t, f, st, ctx, mark in rows[:a.top]:
        print(f"  {w}  {t[:22]:<24} {f[:26]:<28} {st:<4} {mark}")
        print(f"      …{ctx}…")


if __name__ == "__main__":
    main()
