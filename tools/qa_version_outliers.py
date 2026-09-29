# -*- coding: utf-8 -*-
"""版本交叉核对：同一首歌**多个版本**里，只出现在**某一个版本**的长片段 = 候选误读（含"拼接假片段"）。

为什么用"版本"当尺子（2026-09-29 实测）：
  一开始我用"这个片段在**全库**只出现一次"当判据 —— 实测 89.6% 的 11 音窗口都是独证(每首歌本来就
  各不相同), 这个尺子**没有分辨力**。真正有分辨力的是**同一首歌的别的版本**:
  《你怎么说》库里有 5 个版本, 而 `33565653253` 只出现在其中 1 个（`你怎么说_2.txt`，转写时把
  "行尾 `3 -`" 和紧跟的间奏括号 `(5 6 | 5 6 5 3 2` 连读拼出来的假片段）——
  **"同曲多版本里只有它一处"** 才是"可能是转写噪声"的信号。

本工具只读，输出 TSV + 统计：
  * 分组 = 曲名；只用**有 ≥2 个版本**的组（没有兄弟版本可比就无从判断）；
  * 对每组算每个版本独有的 W 音窗口，按"独有窗口数 / 总窗口数"排序；
  * 顺带标出上下文像不像"拼接现场"（近了有念白 `x`、延长 `-` 多）。

用法: py -3.13 tools/qa_version_outliers.py [--w 11] [--top 30] [--check 曲名]
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
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
from lookup import pitch_and_oct     # noqa: E402  与检索同源的音高口径


def load(data):
    groups = collections.defaultdict(list)
    for line in io.open(data, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        p, _o = pitch_and_oct(d.get("score") or "")
        t = (d.get("title") or "").strip()
        if not t or len(p) < 8:
            continue
        groups[t].append({"file": (d.get("file") or [""])[0], "status": d.get("status") or "",
                          "p": p, "sc": d.get("score") or ""})
    return groups


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--w", type=int, default=11)
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--check", default="", help="只看这首歌的独有片段(用来复现某个案例)")
    ap.add_argument("--out", default=os.path.join(ROOT, "train-work", "version_outliers.tsv"))
    a = ap.parse_args()
    W = a.w
    groups = load(a.data)

    if a.check:
        for v in groups.get(a.check, []):
            others = set()
            for v2 in groups[a.check]:
                if v2 is v:
                    continue
                others |= {v2["p"][i:i + W] for i in range(len(v2["p"]) - W + 1)}
            mine = {v["p"][i:i + W] for i in range(len(v["p"]) - W + 1)}
            only = sorted(mine - others)
            print(f"{a.check} · {v['file']} ({v['status']}) 独有 {len(only)} 个 {W} 音窗口:")
            for w in only[:20]:
                i = v["p"].find(w)
                print(f"   {w}   …{v['p'][max(0,i-10):i+W+10]}…")
        return

    rows, total_songs = [], 0
    for t, vs in groups.items():
        if len(vs) < 2:
            continue
        total_songs += len(vs)
        for v in vs:
            others = set()
            for v2 in vs:
                if v2 is not v:
                    others |= {v2["p"][i:i + W] for i in range(len(v2["p"]) - W + 1)}
            mine = [v["p"][i:i + W] for i in range(len(v["p"]) - W + 1)]
            only = [w for w in mine if w not in others]
            if not only:
                continue
            mx = len(re.findall(r"x", v["sc"]))
            dash = len(re.findall(r"(?:^|\s)-(?:\s|$)", v["sc"]))
            mark = []
            if v["status"] == "ocr":
                mark.append("机器转写")
            if mx:
                mark.append(f"念白x{mx}")
            if dash >= 20:
                mark.append(f"延长-{dash}")
            rows.append((t, v["file"], v["status"], len(only), len(mine),
                         len(only) / max(1, len(mine)), " ".join(mark),
                         only[0], v["p"][max(0, v["p"].find(only[0]) - 10):v["p"].find(only[0]) + W + 10]))

    rows.sort(key=lambda r: -r[5])
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with io.open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("曲名\t文件\tstatus\t独有窗口\t总窗口\t独有占比\t标记\t示例片段\t上下文\n")
        for r in rows:
            g.write("\t".join(str(x) for x in r) + "\n")
    n_songs = sum(1 for _t, vs in groups.items() if len(vs) >= 2 for _v in vs)
    print(f"语料 {sum(len(v) for v in groups.values())} 首 · 曲名 {len(groups)} 个 · "
          f"**有兄弟版本可比**的 {n_songs} 首({len([1 for _t, vs in groups.items() if len(vs)>=2])} 组)")
    print(f"其中「有本版独有 {W} 音窗口」的 {len(rows)} 首 -> {a.out}")
    print(f"独有占比最高的 {a.top} 首(越高越可疑: 只有它这一版有这些片段):")
    for t, f, st, only, tot, ratio, mark, seg, ctx in rows[:a.top]:
        print(f"  {ratio*100:5.1f}%  {only:>4}/{tot:<4} {t[:20]:<22} {f[:24]:<26} {st:<4} {mark}")
        print(f"         例: {seg}  …{ctx}…")


if __name__ == "__main__":
    main()
