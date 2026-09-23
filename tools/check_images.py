# -*- coding: utf-8 -*-
"""送进转写之前，先把图片**验一遍** —— 坏图会让转写产出垃圾或直接失败。

2026-09-24 实测（全部历史图 38,359 张）：**492 张不可用**（1.3%）——
  * "细条"图：600x15 / 1182x1 / 233x9（下载被截断，或站点占位条）→ 转出来必然是空/垃圾；
  * 坏 PNG（bad header checksum）、无法识别的文件；
  * 好消息：**没有**把 HTML 错误页存成图的（0 张）。
且**转写队列那 459 个目录 / 711 张图 100% 可用** ✓ —— 队列是干净的。

用法:
    python3 tools/check_images.py <目录或文件...>        # 逐个报异常
    python3 tools/check_images.py --queue               # 直接验"金曲缺口转写队列"里的图
    python3 tools/check_images.py <目录> --min-px 200   # 小于 200x200 就算"细条"
"""
import argparse
import csv
import glob
import os
import sys

EXT = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff")
QUEUE_TSVS = ("金曲缺口_转写队列.tsv", "金曲缺口_转写队列_旧图.tsv")


def looks_html(path):
    try:
        with open(path, "rb") as f:
            head = f.read(200).lstrip().lower()
        return head[:1] == b"<" or b"<html" in head[:120]
    except OSError:
        return False


def check_one(path, min_px):
    from PIL import Image
    try:
        im = Image.open(path)
        im.verify()
        im = Image.open(path)
        w, h = im.size
    except Exception as e:
        return ("HTML错误页" if looks_html(path) else type(e).__name__), str(e)[:50]
    if w < min_px or h < min_px:
        return "细条/截断", f"{w}x{h}"
    return None, f"{w}x{h}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("targets", nargs="*", help="目录或图片")
    ap.add_argument("--queue", action="store_true", help="验转写队列里的图(_analysis/*转写队列*.tsv)")
    ap.add_argument("--min-px", type=int, default=100, help="宽或高小于它就报'细条'")
    ap.add_argument("--analysis", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "_analysis"))
    a = ap.parse_args()

    dirs = []
    if a.queue:
        for t in QUEUE_TSVS:
            p = os.path.join(a.analysis, t)
            if not os.path.isfile(p):
                continue
            for r in csv.DictReader(open(p, encoding="utf-8"), delimiter="\t"):
                d = (r.get("本地目录") or "").strip()
                if d:
                    for base in ("images-prep", os.path.join("..", "images-prep")):
                        if os.path.isdir(os.path.join(base, d)):
                            dirs.append(os.path.join(base, d))
    for t in a.targets:
        if os.path.isdir(t):
            dirs += [os.path.join(t, sub) for sub in sorted(os.listdir(t))] or [t]
        else:
            dirs.append(t)
    if not dirs:
        sys.exit("没找到目标（用 --queue 或给出目录/图片）")

    files = []
    for d in dirs:
        if os.path.isfile(d):
            files.append(d)
        else:
            for f in sorted(os.listdir(d)):
                if f.lower().endswith(EXT):
                    files.append(os.path.join(d, f))
    bad, sizes = [], {}
    for p in files:
        why, info = check_one(p, a.min_px)
        if why:
            bad.append((p, why, info))
        else:
            sizes[info] = sizes.get(info, 0) + 1
    print(f"验了 {len(files)} 张图（{len(dirs)} 个位置）: 正常 {len(files) - len(bad)}, **异常 {len(bad)}**")
    if bad:
        kinds = {}
        for _p, why, _i in bad:
            kinds[why] = kinds.get(why, 0) + 1
        print("  异常类型:", kinds)
        for p, why, info in bad[:15]:
            print(f"   ✗ {p[:78]}  {why} {info}")
    else:
        print("  ✓ 全部可用")
    return 0


if __name__ == "__main__":
    sys.exit(main())
