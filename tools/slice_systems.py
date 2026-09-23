# -*- coding: utf-8 -*-
"""把一张简谱扫描件按**谱表(系统)**切开并放大 —— 给"人眼核对"或"送进 VLM 之前"用。

为什么需要: 整页图动辄 2480x3508, 直接看/直接喂模型都在"缩放到能放下"的过程中丢掉
细节(连音线、减时线、附点、八度点)。按谱表切一条出来再放大, 每个音就看得清了。

做法: 音符行的竖笔(数字/小节线)比歌词行高 —— 按"竖向游程 >= N"的像素数找行,
      连续行聚成带; 再按带裁剪、放大、存盘。

用法:
    python3 tools/slice_systems.py <图片或目录> [--out 输出目录] [--zoom 2.5]
                                   [--min-run 45] [--min-height 20] [--only 3,4]
    # 目录会递归找 *.jpg/*.png/*.jpeg/*.webp/*.gif(会自动转码, 站点常把 GIF 叫 .jpg)

产物: <out>/<图名>__sys01.png ... 以及一份 index.tsv(图 -> 系统数 -> 尺寸)
"""
import argparse
import io
import os
import sys

import numpy as np
from PIL import Image

EXTS = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff")


def find_bands(im, min_run, min_height, thr_ratio=0.18):
    g = im.convert("L")
    a = np.asarray(g)
    H, W = a.shape
    d = a < 140
    run = np.zeros(W, dtype=np.int32)
    cnt = np.zeros(H, dtype=np.int32)
    for y in range(H):
        run = np.where(d[y], run + 1, 0)
        cnt[y] = int((run >= min_run).sum())
    thr = max(3, int(W * 0.0015))
    bands, inb, y0 = [], False, 0
    for y in range(H):
        if cnt[y] > thr and not inb:
            inb, y0 = True, y
        elif cnt[y] <= thr and inb:
            inb = False
            if y - y0 >= min_height:
                bands.append((max(0, y0 - 12), min(H, y + 16)))
    return bands


def one(path, outdir, zoom, min_run, min_height, only):
    im = Image.open(path)
    if im.format in ("GIF", "P") and im.mode != "RGB":
        im = im.convert("RGB")           # 站点常把 GIF/PNG 存成 .jpg 名字
    bands = find_bands(im, min_run, min_height)
    base = os.path.splitext(os.path.basename(path))[0][:60]
    made = 0
    for i, (y0, y1) in enumerate(bands, 1):
        if only and i not in only:
            continue
        c = im.crop((0, y0, im.width, y1))
        if zoom != 1:
            c = c.resize((int(c.width * zoom), int(c.height * zoom)), Image.LANCZOS)
        c.save(os.path.join(outdir, f"{base}__sys{i:02d}.png"))
        made += 1
    return len(bands), made, im.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", help="图片文件或目录")
    ap.add_argument("--out", default="")
    ap.add_argument("--zoom", type=float, default=2.5)
    ap.add_argument("--min-run", type=int, default=45, help="竖笔长度阈值(原图分辨率低就调小)")
    ap.add_argument("--min-height", type=int, default=20)
    ap.add_argument("--only", default="", help="只切这几条, 如 3,4")
    a = ap.parse_args()
    only = {int(x) for x in a.only.split(",") if x.strip().isdigit()} if a.only else None

    targets = []
    if os.path.isdir(a.target):
        for root, _d, files in os.walk(a.target):
            for f in sorted(files):
                if f.lower().endswith(EXTS):
                    targets.append(os.path.join(root, f))
    else:
        targets.append(a.target)
    if not targets:
        sys.exit(f"没找到图片: {a.target}")
    outdir = a.out or os.path.join(os.path.dirname(os.path.abspath(targets[0])), "_systems")
    os.makedirs(outdir, exist_ok=True)

    idx = ["图片\t系统数\t切出\t原尺寸"]
    for p in targets:
        try:
            n, made, size = one(p, outdir, a.zoom, a.min_run, a.min_height, only)
        except Exception as e:
            print(f"  !! {os.path.basename(p)}: {type(e).__name__}: {e}")
            continue
        idx.append(f"{os.path.basename(p)}\t{n}\t{made}\t{size[0]}x{size[1]}")
        print(f"  {os.path.basename(p)[:48]:50s} 系统 {n:2d}, 切出 {made:2d} ({size[0]}x{size[1]})")
    io.open(os.path.join(outdir, "index.tsv"), "w", encoding="utf-8", newline="\n").write("\n".join(idx) + "\n")
    print(f"\n图片 {len(targets)} 张 -> {outdir}  (index.tsv 有清单)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
