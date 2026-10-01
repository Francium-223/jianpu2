# -*- coding: utf-8 -*-
"""**夜间质量抽检**（只读、轻量）—— 在转写流水线跑着的时候也能安全执行。

## 查什么（都是"看一眼就知道要不要处理"的那类）

1. **语料 ↔ 站点索引是否对得上**：曲数、音符数（两边算的口径不同，这里只比曲数与总量级）。
2. **元数据可疑**：曲名里混进站名/分类后缀、空曲名、`source=` 缺失、`link=` 不是具体页（用 linkurl 判，若可用）。
3. **碎片谱**：音符数很少（<20）的曲谱 —— 多半是"多页只转了一页"或转写失败留下的残片。
4. **低置信度**：`conf_p10` 偏低（<0.85）的曲谱 —— 人工复核优先级最高的一批。
5. **同名多版本**：同一 `group` 有多个 `source`（正常，但数字异常大时值得看）。
6. **今天的增量**：最近 24 小时新入库多少首（转写流水线的实际产出率）。

## 为什么单独一个脚本
流水线夜里在跑，`qa_parse_loss.py` / `check_corpus_invariants.py` 要解析全部曲谱（重）；
这个只读 `data.jsonl` + 站点索引，**几秒**出结论，适合"边跑边看"。

用法:
    py -3.13 tools/qa_night_sweep.py
    py -3.13 tools/qa_night_sweep.py --json > qa.json
"""
from __future__ import annotations

import argparse
import collections
import gzip
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SITE = os.environ.get("JIANPU_SITE") or os.path.join(os.path.dirname(ROOT), "jianpu-db.github.io")

# 曲名里不该出现的"站名/分类"后缀（build_web_data 的 popKey 也在剥这些）
JUNK = ("简谱", "歌谱", "五线谱", "正谱", "完整版", "弹唱", "吉他谱", "钢琴谱", "歌曲类")


def _flat(v):
    """把 list（甚至嵌套 list）摊平成可读字符串 —— `data.jsonl` 里的 `file`/`source` 是 list，
    而站点索引里是字符串（两边形状不同，别混）。"""
    if isinstance(v, list):
        return ",".join(_flat(x) for x in v)
    return "" if v is None else str(v)

def load_corpus():
    rows = []
    with io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def index_count():
    p = os.path.join(SITE, "data", "songs.jsonl.gz")
    if not os.path.exists(p):
        return None
    return sum(1 for ln in gzip.open(p, "rb").read().split(b"\n") if ln.strip())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="输出 JSON（给别的脚本用）")
    a = ap.parse_args()

    t0 = time.time()
    rows = load_corpus()
    n = len(rows)
    notes = sum(int(r.get("n_notes") or 0) for r in rows)
    bars = sum(len(r.get("bars") or []) for r in rows)
    idxn = index_count()

    # ② 元数据可疑
    junk_title, empty_title, no_source = [], [], []
    # source 是 list 的行数（数据形状异常，值得知道 —— 2026-10-02 抽检时真发现了这种行）
    source_list = 0
    for r in rows:
        t = (r.get("title") or "").strip()
        if not t:
            empty_title.append(_flat(r.get("file")))
        elif any(t.endswith(j) for j in JUNK) or any(j + "(" in t or j + "（" in t for j in JUNK):
            junk_title.append((t, _flat(r.get("file"))))
        # ⚠ 2026-10-02 抽检发现: `source` 在部分行里是 **list**（不是字符串）—— 下游按字符串用会出怪事
        #   （`search.ts` 的"按 source 去重版本"就是把它拼进 Set）。这里既做防御，也统计形状异常。
        s = r.get("source")
        if isinstance(s, list):
            source_list += 1
            if not s:
                no_source.append(_flat(r.get("file")))
        elif not (s or "").strip():
            no_source.append(r.get("file"))

    # ③ 碎片谱 / ④ 低置信度
    tiny = sorted(((int(r.get("n_notes") or 0), r.get("title"), _flat(r.get("file"))) for r in rows
                   if int(r.get("n_notes") or 0) < 20), key=lambda x: x[0])
    lowconf = []
    for r in rows:
        try:
            c = float(r.get("conf_p10") or "")
        except (TypeError, ValueError):
            continue
        if c < 0.85:
            lowconf.append((round(c, 3), r.get("title"), _flat(r.get("file"))))
    lowconf.sort()

    # ⑤ 同名多版本
    groups = collections.Counter((r.get("title") or "").strip() for r in rows)
    multi = [(g, c) for g, c in groups.most_common(8) if c > 1]

    # ⑥ 24 小时增量 —— **用 git 历史**，不用 mtime。
    #   第一版用 mtime 统计，得出"近 24 小时新入库 23,982 份"，而 scores/ 一共才 24,011 份 ——
    #   明显是错的: 流水线重建/重写会让整目录 mtime 变新。git 历史才是"真的新增了哪些文件"。
    sdir = os.path.join(DB, "scores")
    new_scores = 0
    try:
        import subprocess
        r = subprocess.run(["git", "log", "--since=24.hours", "--name-only", "--pretty=format:",
                            "--", "scores/"], cwd=DB, capture_output=True, text=True, timeout=60)
        new_scores = len({ln.strip() for ln in (r.stdout or "").splitlines() if ln.strip()})
    except Exception:
        new_scores = -1        # 取不到就标 -1，别报一个假数

    out = {
        "corpus_songs": n, "corpus_notes": notes, "corpus_bars": bars, "index_rows": idxn,
        "scores_files": len(os.listdir(sdir)) if os.path.isdir(sdir) else 0,
        "new_scores_24h_git": new_scores,
        "junk_title": len(junk_title), "empty_title": len(empty_title), "no_source": len(no_source),
        "tiny_scores": len(tiny), "low_conf_p10": len(lowconf), "source_is_list": source_list,
        "elapsed_s": round(time.time() - t0, 1),
    }
    if a.json:
        print(json.dumps({"summary": out, "tiny_top": tiny[:10], "lowconf_top": lowconf[:10],
                          "junk_top": junk_title[:5], "multi_top": multi}, ensure_ascii=False, indent=2))
        return 0

    print(f"=== 夜间质量抽检（{time.strftime('%m-%d %H:%M')}）· 用时 {out['elapsed_s']}s ===")
    print(f"  语料 {n:,} 首 / {notes:,} 音符 / {bars:,} 小节线 · 曲谱文件 {out['scores_files']:,}")
    print(f"  站点索引 {idxn if idxn is not None else '(读不到)'} 行"
          + ("  ✓ 与语料一致" if idxn == n else "  ⚠ 与语料不一致（重建索引？）"))
    print("  近 24 小时新入库 " + (f"{new_scores:,} 份（git 历史）" if new_scores >= 0 else "(取不到 git 历史)"))
    print()
    print(f"  ① 曲名可疑（带站名/分类后缀） {len(junk_title)}")
    for t, f in junk_title[:4]:
        print(f"       {t}   [{f}]")
    print(f"  ② 空曲名 {len(empty_title)}" + (f"  例: {empty_title[:3]}" if empty_title else ""))
    print(f"  ③ source 是 list 的行 {source_list} · 缺 source= {len(no_source)}" + (f"  例: {no_source[:3]}" if no_source else ""))
    print(f"  ④ 碎片谱（<20 音） {len(tiny)}  最小的几个:")
    for nn, t, f in tiny[:5]:
        print(f"       {nn:>4} 音  {t}  [{f}]")
    print(f"  ⑤ 低置信度（conf_p10 < 0.85） {len(lowconf)}  最低的几个:")
    for c, t, f in lowconf[:5]:
        print(f"       {c}  {t}  [{f}]")
    print(f"  ⑥ 同名多版本（取多版本最多的 5 个）:")
    for g, c in multi[:5]:
        print(f"       {c:>3} 版  {g}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
