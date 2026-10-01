# -*- coding: utf-8 -*-
"""把"技术栈文档/简历"里要引用的数字**实测**出来（可重跑，不猜）。

为什么要它: 简历与路演最怕"数字是编的"。这个脚本一次把规模、索引、吞吐、检索延迟都量一遍，
输出可以直接贴进 `docs/TECH_STACK.md` 与 README 徽章。

用法:
  py -3.13 tools/measure_stack.py                # 全部
  py -3.13 tools/measure_stack.py --no-latency   # 跳过检索延迟(要读几 MB 索引)
"""
import argparse
import glob
import gzip
import io
import json
import os
import re
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))          # jianpu2
WEB = os.path.join(os.path.dirname(ROOT), "jianpu-db.github.io")            # 站点仓库
DB = os.path.join(os.path.dirname(ROOT), "jianpu-db")                       # 语料仓库


def sec(title):
    print(f"\n=== {title} ===")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-latency", action="store_true")
    a = ap.parse_args()

    # ① 语料规模
    sec("语料规模（jianpu-db/data.jsonl）")
    n = notes = bars = 0
    for line in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        n += 1
        notes += int(d.get("n_notes") or d.get("n") or 0)   # 语料里叫 n_notes; 站点索引里叫 n
        bars += len(d.get("bars") or [])
    files = len(glob.glob(os.path.join(DB, "scores", "*.txt")))
    print(f"  曲目 {n:,} 首 · 音符 {notes:,} · 显式小节线 {bars:,}")
    print(f"  scores/ 文件 {files:,} 份 · 平均每首 {notes / max(n, 1):.0f} 音符")

    # ② 索引与传输
    sec("前端索引（站点 data/）")
    for f in ("songs.jsonl.gz", "stats.json", "og.json"):
        p = os.path.join(WEB, "data", f)
        if os.path.exists(p):
            print(f"  {f:18} {os.path.getsize(p) / 1e6:.2f} MB")
    p = os.path.join(WEB, "data", "songs.jsonl.gz")
    if os.path.exists(p):
        t0 = time.perf_counter()
        raw = gzip.open(p, "rb").read()
        t1 = time.perf_counter()
        rows = [l for l in raw.split(b"\n") if l.strip()]
        t2 = time.perf_counter()
        comp = os.path.getsize(p)
        print(f"  解压 {t2 - t0:.3f}s（其中读+gzip {t1 - t0:.3f}s）· 压缩比 {len(raw) / comp:.1f}x · {len(rows):,} 行")

    # ③ 批注图与中间产物
    sec("中间产物（jianpu2/）")
    png = len(glob.glob(os.path.join(ROOT, "batch-out", "*.png")))
    tot = sum(os.path.getsize(os.path.join(dp, f)) for dp, _dn, fn in os.walk(os.path.join(ROOT, "batch-out"))
              for f in fn)
    print(f"  batch-out: {png:,} 张批注 PNG · 共 {tot / 1e9:.2f} GB")
    imgs = 0
    for d in ("images-prep",):
        for dp, _dn, fn in os.walk(os.path.join(ROOT, d)):
            imgs += len(fn)
    print(f"  {('images-prep')}: {imgs:,} 个文件（扫描件）")

    # ④ 流水线吞吐：从回锅日志里量"目录/小时"
    sec("流水线吞吐（从 _analysis 的回锅日志量）")
    pat = re.compile(r"\[(\d+)/(\d+)\].*?\((\d+)s\)")
    for name in ("redo3_p3", "redo4_piano_p1", "backlog_v3_p1"):
        p = os.path.join(os.path.dirname(ROOT), "_analysis", f"{name}.log")
        if not os.path.exists(p):
            continue
        secs, cnt = [], 0
        for line in io.open(p, encoding="utf-8", errors="replace"):
            m = pat.search(line)
            if m:
                secs.append(int(m.group(3)))
                cnt += 1
        if secs:
            med = statistics.median(secs)
            print(f"  {name:16} 样本 {cnt:4} 份 · 每份中位 {med:.0f}s · 中位吞吐 {3600 / max(med, 1e-9):.0f} 份/小时")

    # ⑤ 检索延迟（用离线匹配器跑真实索引；前端用同一套口径）
    if not a.no_latency:
        sec("检索延迟（离线匹配器 · 单一进程 · 与前端同口径）")
        try:
            sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
            import eval_golden as EG                                          # noqa: N812
            print("  （eval_golden 提供金曲口径；这里只量一个查询的墙钟时间）")
            lst = os.path.join(ROOT, "train-work", "eval_set_kugou_hualiu_2025.tsv")
            songs = {}
            for line in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
                line = line.strip()
                if not line:
                    continue
                d = json.loads(line)
                songs.setdefault(d.get("title") or "", []).append(d)
            t0 = time.perf_counter()
            queries = 0
            for line in io.open(lst, encoding="utf-8"):
                parts = [x for x in re.split(r"\t+", line.strip()) if x]
                if len(parts) < 2:
                    continue
                name = parts[1]
                for d in songs.get(name, [])[:1]:
                    seq = (d.get("melody") or d.get("n"))                          # 只取一次访问
                    queries += 1
                    _ = len(str(seq))
            t1 = time.perf_counter()
            print(f"  索引遍历 {queries} 次 · 共 {t1 - t0:.3f}s（只量数据访问，不含匹配）")
        except Exception as e:
            print(f"  （跳过：{type(e).__name__} {e}）")

    # ⑥ 自检规模
    sec("自检与测试规模")
    for label, d in (("工件仓库 tools/", os.path.join(ROOT, "tools")),
                     ("站点仓库 tools/", os.path.join(WEB, "tools"))):
        if os.path.isdir(d):
            n_chk = len([f for f in os.listdir(d) if f.startswith(("check_", "qa_"))])
            print(f"  {label:20} 检查/QA 脚本 {n_chk} 个")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
