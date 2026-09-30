# -*- coding: utf-8 -*-
"""把**成品目录里的元数据**补进语料里"那一栏还空着"的曲谱（只填空栏，绝不覆盖人工写的）。

## 为什么需要它（2026-09-30 实测）

流水线是两段式：`batch-out` --to_jianpu_db--> `jianpu-db-out/scores`（成品/暂存）--> `jianpu-db/scores`
（语料）。第二段用的是 `import_finished_scores.py`，它是**只拷不覆盖**（保护人工修改）——
于是"成品里新填的元数据（人标/歌手/别名/收录页/MBID）"对于**已经在语料里**的那些谱**进不去**。

实测：成品里带 `usertag` 且语料里有同曲的 **7,411 份**，其中语料**空着**的有 **2,006 份**。
（另外 5,405 份是之前那轮就已经进语料的。）

## 口径（保守）

* **只填语料里那一栏为空的字段**；语料里已有值的一律不动（人工改过的优先）。
* 只碰**元数据行**，正文（音符号）一个字节都不改。
* 字段白名单：`usertag` / `artist` / `alias` / `link` / `MBID`（这几条是页面上可人工编辑的）。
* 匹配顺序：先按**文件名**（`jianpu-db-out/scores/<名>.txt` ↔ `jianpu-db/scores/<名>.txt`），
  名字对不上再按 `source=`（同一次抓取）。
* 默认 dry-run。

用法:
  py -3.13 tools/merge_metadata_into_corpus.py            # 只报告
  py -3.13 tools/merge_metadata_into_corpus.py --apply    # 真填
"""
import argparse
import glob
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

ROOT = r"D:\Documents_D\jianpu2"
DB = r"D:\Documents_D\jianpu-db"
FIELDS = ("usertag", "artist", "alias", "link", "MBID")


def read_fields(path):
    t = io.open(path, encoding="utf-8", errors="replace").read()
    out = {}
    for f in FIELDS:
        m = re.search(r"(?m)^" + f + r"=(.*)$", t)
        out[f] = (m.group(1).strip() if m else "")
    m = re.search(r"(?m)^source=(\S+)$", t)
    out["_src"] = m.group(1) if m else ""
    return out, t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "jianpu-db-out", "scores"))
    ap.add_argument("--dst", default=os.path.join(DB, "scores"))
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    staging = {}
    by_src = {}
    for p in glob.glob(os.path.join(a.src, "*.txt")):
        b = os.path.basename(p)
        if b.endswith("_buf.txt") or b.endswith("_expand.txt"):
            continue
        try:
            f, _t = read_fields(p)
        except OSError:
            continue
        staging[b] = (p, f)
        if f["_src"]:
            by_src.setdefault(f["_src"], (p, f))

    plans, stat = [], {}
    for p in glob.glob(os.path.join(a.dst, "*.txt")):
        b = os.path.basename(p)
        if b.endswith("_buf.txt") or b.endswith("_expand.txt"):
            continue
        try:
            cf, craw = read_fields(p)
        except OSError:
            continue
        sp = staging.get(b) or (by_src.get(cf["_src"]) if cf["_src"] else None)
        if not sp:
            continue
        _sp_path, sf = sp
        for f in FIELDS:
            if cf[f] or not sf[f]:                 # 语料已有值 / 成品也没有 -> 跳过
                continue
            plans.append((b, f, sf[f]))
            stat[f] = stat.get(f, 0) + 1

    print(f"成品 {len(staging)} 份 · 语料文件 {len(glob.glob(os.path.join(a.dst, '*.txt')))} 份")
    print(f"**可以补的空栏：{len(plans)} 处**（只填语料里空的，已有值的不动）")
    for f, n in sorted(stat.items(), key=lambda x: -x[1]):
        print(f"   {f:<8}{n:>6}")
    for b, f, v in plans[:12]:
        print(f"   例: {b[:28]:<30} {f}={v[:40]}")
    if not a.apply:
        print("\n(dry-run，没写任何东西；加 --apply 才填)")
        return 0

    done = skipped = 0
    cache = {}
    for b, f, v in plans:
        p = os.path.join(a.dst, b)
        raw = cache.get(p)
        if raw is None:
            raw = io.open(p, encoding="utf-8", errors="replace", newline="").read()
        nl = "\r\n" if "\r\n" in raw else "\n"
        # ⚠ 必须容忍 CRLF：`$` 在 `(?m)` 下匹配的是 `\n` 之前的位置，而 CRLF 行尾是 `\r\n` ——
        #   写成 `[ \t]*$` 时**一行都匹配不上**（实测第一版就是这样：dry-run 报 2,153 处，
        #   apply 却"已填 0 处"，因为全落进了下面的 elif 被跳过）。所以统一用 `[ \t]*\r?$`。
        if re.search(r"(?m)^" + f + r"=[ \t]*\r?$", raw):
            raw = re.sub(r"(?m)^" + f + r"=[ \t]*\r?$", f + "=" + v, raw, count=1)
            cache[p] = raw
            done += 1
        elif re.search(r"(?m)^" + f + r"=[ \t]*\S", raw):
            skipped += 1                            # 已经有值(不该发生) -> 不动
        else:
            raw = raw.replace("%--", f + "=" + v + nl + "%--", 1)
            cache[p] = raw
            done += 1
    for p, raw in cache.items():
        io.open(p, "w", encoding="utf-8", newline="").write(raw)
    print(f"\n已填 {done} 处（写了 {len(cache)} 个文件）" + (f"；跳过 {skipped} 处(已有值)" if skipped else ""))
    print("下一步: `py -3.13 parse_scores.py`(在 jianpu-db 里) 重建 data.json(l) 并提交。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
