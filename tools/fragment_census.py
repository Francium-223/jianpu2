# -*- coding: utf-8 -*-
"""**全库碎片普查**：按"每页音节数"找出可疑的转写（比"整首 <20 音"准）。

## 为什么需要它
我最初的碎片判据是"整首音节 <20"，那会**漏掉**"3 页谱只转出 30 个音"这类 ——
每页 10 个音同样离谱，但整首数 >20 就不报警。用**每页**比值才接近真实情况。

## 口径（都可解释）
* 页数 = 该谱**原图张数**（`images-prep/<batch>/<曲谱名>/` 下的图片数；拆页 `__pgN` 也计入）；
* 音节数 = `data.jsonl` 的 `n_notes`（只数音高，不含休止）；
* 阈值: **每页 < 15 音** → 可疑（正常简谱一页几十到几百个音；15 已经非常宽松）。
  另外单独列出"一页都没找到"（原图已清理）—— 那些**查不下去**，不算在可疑里。

## 只读
不改任何东西；输出一份清单 + 按来源的分布，供决定"要不要修、从哪儿修"。

用法:
    py -3.13 tools/fragment_census.py                    # 全库普查
    py -3.13 tools/fragment_census.py --per-page 20      # 换阈值
    py -3.13 tools/fragment_census.py --out 清单.txt
"""
from __future__ import annotations

import argparse
import collections
import glob
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.dirname(ROOT)
DB = os.path.join(WS, "jianpu-db")
IMG_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")


def image_index():
    """曲谱名 -> 原图张数。目录就在 images-prep/<batch>/<曲谱名>/（**两层**，别再只查一层）。"""
    idx = {}
    for base in ("images-prep", "images"):
        root = os.path.join(ROOT, base)
        if not os.path.isdir(root):
            continue
        for batch in os.listdir(root):
            p = os.path.join(root, batch)
            if not os.path.isdir(p):
                continue
            for name in os.listdir(p):
                d = os.path.join(p, name)
                if not os.path.isdir(d):
                    continue
                n = 0
                try:
                    for f in os.listdir(d):
                        ext = os.path.splitext(f)[1].lower()
                        # ⚠ 排除两类"不是页"的图（不然页数会被算爆）:
                        #   `__pgN` = 拆页（同一页的下半张）；`_strip_NN` = jianpujia 那种**一条条小切片**
                        #   实测: 不排除切片时《七色光之歌》被算成"27 页"（儿歌哪来 27 页），比值全失真。
                        if ext in IMG_EXTS and "__pg" not in f and "_strip_" not in f:
                            n += 1
                except OSError:
                    continue
                if n:
                    # ⚠ 键是 **source id**（目录名里 `__` 之后那段），不是曲谱名！
                    #   语料的 `file` 是标题式（`爱错.txt`），而目录名是 `<曲名>__<source>`
                    #   —— 第一版按文件名匹配 → **99.5% 查不到原图**，得出一堆假数。
                    #   （同类"匹配键/路径"错误今晚犯了三次；所以下面加了命中率自检。）
                    key = name.split("__")[-1] if "__" in name else name
                    idx[key] = max(idx.get(key, 0), n)
    return idx


def _flat(v):
    if isinstance(v, list):
        return ",".join(_flat(x) for x in v)
    return "" if v is None else str(v)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-page", type=float, default=15.0, help="每页音节数低于它就报可疑（默认 15）")
    ap.add_argument("--out", default="", help="把可疑清单写到这个文件")
    a = ap.parse_args()

    imgs = image_index()
    print(f"原图目录索引: {len(imgs):,} 个 source")

    rows = 0
    hit = miss = 0
    suspect, noimg, ok = [], [], 0
    for line in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        rows += 1
        stem = os.path.splitext(_flat(r.get("file")).split(",")[0])[0]
        srcs = r.get("source") or []
        src0 = (srcs[0] if isinstance(srcs, list) and srcs else (srcs if isinstance(srcs, str) else "")) or ""
        n_img = imgs.get(src0, 0) or imgs.get(stem, 0)
        n_notes = int(r.get("n_notes") or 0)
        if n_img == 0:
            miss += 1
            noimg.append((n_notes, r.get("title"), stem))
        else:
            hit += 1
        if n_img == 0:
            pass
        elif n_notes / n_img < a.per_page:
            suspect.append((round(n_notes / n_img, 1), n_notes, n_img, r.get("title"), stem, _flat(r.get("source"))))
        else:
            ok += 1

    suspect.sort()
    # **自检**: 命中率太低就说明匹配键又错了（第一版 0.5% 命中，一眼可见）
    print(f"原图匹配: 命中 {hit:,} / 查不到 {miss:,}（{hit*100.0/max(1,rows):.1f}% 命中）")
    print(f"\n语料 {rows:,} 行：")
    print(f"  ✓ 每页 ≥{a.per_page:g} 音（正常）: {ok:,}（{ok*100.0/rows:.1f}%）")
    print(f"  ⚠ 每页 <{a.per_page:g} 音（**可疑**）: {len(suspect):,}（{len(suspect)*100.0/rows:.1f}%）")
    print(f"  ·  找不到原图（查不下去）: {len(noimg):,}（{len(noimg)*100.0/rows:.1f}%）")

    if suspect:
        print("\n最可疑的 12 份（每页音数升序）:")
        for ratio, nn, ni, t, stem, src in suspect[:12]:
            print(f"  {ratio:>6} 音/页  {nn:>5} 音 / {ni} 页  {str(t)[:24]:<24} [{src}]")
        by_src = collections.Counter(s.split("-")[0] or "?" for *_x, s in suspect)
        print("\n按来源:", dict(by_src.most_common()))

    if a.out:
        with io.open(a.out, "w", encoding="utf-8", newline="\n") as f:
            f.write(f"# 全库碎片普查（阈值: 每页 <{a.per_page:g} 音）\n")
            f.write("# 每页音数\t音节数\t页数\t曲名\t曲谱名\tsource\n")
            for ratio, nn, ni, t, stem, src in suspect:
                f.write(f"{ratio}\t{nn}\t{ni}\t{t}\t{stem}\t{src}\n")
        print(f"\n清单已写: {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
