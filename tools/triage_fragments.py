# -*- coding: utf-8 -*-
"""把"碎片谱（<20 音）"**分类**：哪些真该重转，哪些本来就是短曲。

## 为什么要分类
抽检给出 80 份碎片谱，但它们的成因完全不同：
  * **多页谱只转了第一页** -> 原图有 ≥2 张 -> **该重转**；
  * **织体判据把某几页丢了**（sidecar 里 `dropped_pages > 0`）-> **该重转**（且要先看判据该不该放宽）；
  * **本来就是短曲**（儿歌、练习曲、只有一句的谱）-> 原图 1 张、没丢页 -> **不用管**；
  * **原图都找不到**（老目录已清理）-> 只能人工看。

判据都用**产物里已有的证据**（原图张数、batch-out 的 sidecar），不靠猜。

用法:
    py -3.13 tools/triage_fragments.py                       # 读 _analysis/qa_fragments.txt
    py -3.13 tools/triage_fragments.py --in other.txt --out triaged.txt
"""
from __future__ import annotations

import argparse
import glob
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)                       # 工作区根（images-prep/ 就在这下面）
IMG_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")


def image_dirs():
    """一次性列出 images-prep/images 下的所有 `<名字>__<source>` 目录（只列一层，够快）。"""
    out = {}
    # ⚠ 原图目录在 **ROOT**（jianpu2/）下，不是工作区根 —— 第一版写成 WS 于是 80 份全都"找不到原图"。
    for base in (os.path.join(ROOT, "images-prep"), os.path.join(ROOT, "images")):
        for top in os.listdir(base) if os.path.isdir(base) else []:
            p = os.path.join(base, top)
            if not os.path.isdir(p):
                continue
            for d in os.listdir(p):
                full = os.path.join(p, d)
                if os.path.isdir(full):
                    out.setdefault(d, []).append(full)
                    # 原图目录名是 `<曲名>__<source>`，而曲谱文件名**不带** source ——
                    # 所以还要按"`__` 之前的部分"建一个前缀索引（实测: `宫廷宴舞` 的图在
                    # `宫廷宴舞__jianpucn-280697` 里，第一版按全名找 -> 79 份全落空）。
                    out.setdefault("~" + d.split("__")[0], []).append(full)
    return out


def source_of_files():
    """`曲谱文件名 -> source`（data.jsonl 里 file/source 都是 list）。"""
    m = {}
    p = os.path.join(WS, "jianpu-db", "data.jsonl")
    if not os.path.exists(p):
        return m
    for line in io.open(p, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        src = r.get("source")
        src = src[0] if isinstance(src, list) and src else (src if isinstance(src, str) else "")
        for f in (r.get("file") or []):
            if isinstance(f, str):
                m[os.path.splitext(f)[0]] = src or ""
    return m


def count_images(dirs):
    n = 0
    for d in dirs:
        for f in os.listdir(d):
            if os.path.splitext(f)[1].lower() in IMG_EXTS:
                n += 1
    return n


def sidecar_of(stem):
    """batch-out/<stem>.json —— 转写时写的诊断（含 dropped_pages）。"""
    for base in ("batch-out", "batch-out-dup", "batch-out-multipage-old"):
        p = os.path.join(ROOT, base, stem + ".json")
        if os.path.exists(p):
            try:
                return base, json.load(io.open(p, encoding="utf-8"))
            except Exception:
                return base, None
    return None, None


def main() -> int:
    ap = argparse.ArgumentParser()
    # ⚠ 默认路径注意: `WS` 就是 `D:\Documents_D`，`_analysis` 就在它下面 ——
    #   第一版写成 `os.path.dirname(WS)`，于是拼出 `D:\_analysis\...`（不存在）。
    ap.add_argument("--in", dest="src", default=os.path.join(WS, "_analysis", "qa_fragments.txt"))
    ap.add_argument("--out", dest="dst", default=os.path.join(WS, "_analysis", "qa_fragments_triaged.txt"))
    a = ap.parse_args()

    if not os.path.exists(a.src):
        print(f"  找不到输入清单: {a.src}（先跑 tools/qa_night_sweep.py --lists <dir>）")
        return 1

    rows = []
    for line in io.open(a.src, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 3:
            rows.append((int(parts[0]), parts[1], parts[2]))

    dirs = image_dirs()
    srcmap = source_of_files()
    buckets = {"多页未转全": [], "丢页(判据)": [], "本来就是短曲": [], "找不到原图": []}
    for notes, title, fname in rows:
        stem = os.path.splitext(os.path.basename(fname))[0]
        d = dirs.get(stem) or dirs.get("~" + stem) or []
        if len(d) > 1:
            want = srcmap.get(stem, "")
            pref = [x for x in d if want and want in os.path.basename(x)]
            if pref:
                d = pref                      # 同名前缀有多个目录时，按 source 认领
        nimg = count_images(d) if d else 0
        base, sc = sidecar_of(stem)
        dropped = 0
        pages = 0
        if isinstance(sc, dict):
            dropped = int(sc.get("dropped_pages") or 0)
            pn = sc.get("page_notes")
            pages = len(pn) if isinstance(pn, list) else 0
        if not d:
            buckets["找不到原图"].append((notes, title, fname, nimg, dropped))
        elif dropped > 0:
            buckets["丢页(判据)"].append((notes, title, fname, nimg, dropped))
        elif nimg >= 2 or pages >= 2:
            buckets["多页未转全"].append((notes, title, fname, nimg, dropped))
        else:
            buckets["本来就是短曲"].append((notes, title, fname, nimg, dropped))

    with io.open(a.dst, "w", encoding="utf-8", newline="\n") as f:
        f.write("# 碎片谱分类（<20 音，共 %d 份）—— 判据: 原图张数 + sidecar 的 dropped_pages/page_notes\n" % len(rows))
        f.write("# 「多页未转全」和「丢页(判据)」这两类**该重转**；「本来就是短曲」不用管。\n")
        f.write("# 重转用法: 把下面第一列名字（去掉扩展名）写进 train-work/redo_*.txt，再跑 tools/transcribe_source.py\n")
        for k in ("丢页(判据)", "多页未转全", "找不到原图", "本来就是短曲"):
            f.write("\n## %s（%d）\n" % (k, len(buckets[k])))
            f.write("# 音符\t曲名\t文件\t原图张数\tdropped_pages\n")
            for notes, title, fname, nimg, dropped in sorted(buckets[k]):
                f.write("%d\t%s\t%s\t%d\t%d\n" % (notes, title, fname, nimg, dropped))

    print("=== 碎片谱分类（%d 份）===" % len(rows))
    for k in ("丢页(判据)", "多页未转全", "找不到原图", "本来就是短曲"):
        print("  %-12s %3d" % (k, len(buckets[k])))
    need = len(buckets["丢页(判据)"]) + len(buckets["多页未转全"])
    print("  -> **该重转 %d 份**；清单写到: %s" % (need, a.dst))
    for k in ("丢页(判据)", "多页未转全"):
        for notes, title, fname, nimg, dropped in sorted(buckets[k])[:4]:
            print("       %4d 音  %-22s 原图 %d 张 丢页 %d" % (notes, title[:22], nimg, dropped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
