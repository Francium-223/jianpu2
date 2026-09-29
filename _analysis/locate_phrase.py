# -*- coding: utf-8 -*-
"""在《你怎么说》的**原谱扫描图**上定位 `33565653253` 这一句 —— 用转写模型逐行回读, 找出哪一行有它。

为什么要这么绕: 管线只存"整页转写的 token 顺序", **不存每个音符的坐标**, 所以"第 83 个音在哪一像素"
没有现成答案。可靠的办法是"逐行切出来重新认一遍": 行是这张图天然的定位单位(用户问的就是
"圈出它在哪"), 认出来哪一行含这串数字, 就把那行圈上; 进一步可把该行再切两半, 缩小到具体小节。

只读原图; 只在 %TEMP% 里写临时裁图。用法: py -3.13 _analysis/locate_phrase.py
"""
import os
import re
import sys

sys.path.insert(0, r"D:\Documents_D\jianpu2\tools")
os.chdir(r"D:\Documents_D\jianpu2")
import numpy as np                       # noqa: E402
from PIL import Image                    # noqa: E402
import transcribe as T                   # noqa: E402
import jp_transcribe as JP               # noqa: E402

IMG = r"images-prep\jianpucn-denglijun\你怎么说（补临时声部）__jianpucn-451637\001.jpg"
QUERY = "33565653253"
TMP = os.environ["TEMP"]


def digits_of(toks):
    out = []
    for t in toks:
        m = re.search(r"[1-7]", t)
        if m and not t.endswith("["):        # `3[` 是三连音开记号, 不是音符
            out.append(m.group(0))
    return "".join(out)


def ocr_crop(im, y0, y1, tag):
    p = os.path.join(TMP, f"loc_{tag}.png")
    im.crop((0, y0, im.size[0], y1)).save(p)
    toks, _meta = JP.render(p, os.path.join(TMP, f"loc_{tag}_r.png"))
    return digits_of(toks)


def main():
    im = Image.open(IMG)
    W, H = im.size
    arr = np.asarray(im.convert("L"))
    rows = T.fine_rows(arr < T.TOL, T.ROW_GAP)
    # 把"内容行块"按间隙聚成**音乐行**
    lines, cur = [], [rows[0]]
    for s, e in rows[1:]:
        if s - cur[-1][1] > 16:
            lines.append((cur[0][0], cur[-1][1]))
            cur = [(s, e)]
        else:
            cur.append((s, e))
    lines.append((cur[0][0], cur[-1][1]))
    print(f"图 {W}x{H} · 内容行块 {len(rows)} · 聚成音乐行 {len(lines)}", flush=True)

    for i, (y0, y1) in enumerate(lines):
        if y1 - y0 < 25:                      # 太窄: 标题/歌词行块
            print(f"  行{i:>2} y{y0}-{y1} 太窄, 跳过", flush=True)
            continue
        d = ocr_crop(im, max(0, y0 - 8), min(H, y1 + 8), f"line{i}")
        hit = QUERY in d
        print(f"  行{i:>2} y{y0}-{y1} 认到 {len(d)} 音 {'<<< 命中 ' + QUERY if hit else ''}", flush=True)
        print(f"        {d[:80]}", flush=True)
        if hit:
            # 再把这行切两半, 缩小到半行
            for half, (a, b) in enumerate(((y0, (y0 + y1) // 2), ((y0 + y1) // 2, y1))):
                d2 = ocr_crop(im, max(0, a - 8), min(H, b + 8), f"line{i}h{half}")
                print(f"       半行{half} y{a}-{b}: {d2}  {'<<< 命中' if QUERY in d2 else ''}", flush=True)


if __name__ == "__main__":
    main()
