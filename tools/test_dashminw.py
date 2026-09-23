# -*- coding: utf-8 -*-
"""量 JP_DASHMINW 下调的**风险**: 会不会把"短下划线碎片"误当延音杠。

不需要模型: dash 块的 token 是硬编码的 `-`(见 transcribe_qwen), 所以只要数
"被 classify_block 判成 dash 的块" 有多少即可。纯 CPU。

用法: py -3.13 tools/test_dashminw.py [抽样数, 默认150]
"""
import glob
import os
import random
import statistics
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np
from PIL import Image
import transcribe as T
from classify_block import classify_block

N = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 150


def load(im_path):
    im = Image.open(im_path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 950 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    return np.asarray(im) < T.TOL


def count_dash(content):
    """整页里被判成 dash 的块数。"""
    n = 0
    bands = []
    for s0, e0 in T.fine_rows(content, T.ROW_GAP):
        bands += T.split_row_inner(content, s0, e0)
    for s, e in bands:
        sub = content[s:e + 1]
        try:
            regions = T.crop_note_regions(sub)
        except Exception:
            continue
        for (x0, x1, y0, y1) in regions:
            crop = sub[max(0, y0):y1 + 1, max(0, x0):x1 + 1]
            if crop.size == 0:
                continue
            try:
                if classify_block(crop) == "dash":
                    n += 1
            except Exception:
                pass
    return n


def run(tag, dashminw, idx, names):
    os.environ["JP_DASHMINW"] = str(dashminw)
    got = []
    for nm in names:
        d = idx.get(nm)
        if not d:
            continue
        try:
            p = __import__("batch_transcribe").pick_page(d)
            got.append(count_dash(load(p)))
        except Exception:
            continue
    tot = sum(got)
    print(f"{tag}(DASHMINW={dashminw}): 页 {len(got)}   dash 块合计 {tot}   "
          f"中位 {statistics.median(got):.0f}   0 杠的页 {sum(1 for g in got if g == 0)}", flush=True)
    return got


def build_affected(out_path):
    """扫描**全部**语料谱, 挑出"阈值 12->8 会新增 dash 块"的那些, 写成定向重跑名单。

    依据(已由 tools/check_dash_equiv.py 实测 ✓): 12->8 是纯放宽, 只会多出 dash 块,
    所以**没有新增候选的谱输出逐字节不变** -> 不必重跑。
    名单格式 = transcribe_source.py 认的"每行一个目录名"。"""
    import batch_transcribe as BT
    idx = {}
    for d in glob.glob("images-prep/*/*"):
        if os.path.isdir(d):
            idx[BT.safe_name(os.path.basename(d))] = d
    names = [os.path.basename(f)[:-4] for f in sorted(glob.glob("batch-out/*.txt"))
             if not os.path.basename(f).startswith("hot_")]
    print(f"语料 {len(names)} 个; 图索引 {len(idx)}", flush=True)
    aff = []
    miss = err = 0
    for i, nm in enumerate(names, 1):
        d = idx.get(nm)
        if not d:
            miss += 1
            continue
        try:
            p = BT.pick_page(d)
            if not p:
                miss += 1
                continue
            content = load(p)
            os.environ["JP_DASHMINW"] = "12"
            n12 = count_dash(content)
            os.environ["JP_DASHMINW"] = "8"
            n8 = count_dash(content)
            if n8 > n12:
                aff.append(os.path.basename(d.rstrip("/\\")))
        except Exception:
            err += 1
        if i % 500 == 0:
            print(f"  {i}/{len(names)}  受影响 {len(aff)}", flush=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(aff) + "\n")
    print(f"\n受影响 {len(aff)} / {len(names)} ({100*len(aff)/max(len(names),1):.0f}%) -> {out_path}"
          f"   (缺目录 {miss}, 异常 {err})", flush=True)


import batch_transcribe as _BT

_idx = {}
for _d in glob.glob("images-prep/*/*"):
    if os.path.isdir(_d):
        _idx[_BT.safe_name(os.path.basename(_d))] = _d
print(f"图索引 {len(_idx)}", flush=True)
_all = [os.path.basename(f)[:-4] for f in sorted(glob.glob("batch-out/*.txt"))
        if not os.path.basename(f).startswith("hot_")]
random.seed(17)
random.shuffle(_all)
_all = _all[:N]

if "--list" in sys.argv:
    i = sys.argv.index("--list")
    build_affected(sys.argv[i + 1] if len(sys.argv) > i + 1 else "train-work/dash_affected.txt")
    sys.exit(0)

a = run("基线", 12, _idx, _all)
b = run("下调", 8, _idx, _all)
print(f"\n  -> 杠块总数 {sum(a)} -> {sum(b)}  ({100*(sum(b)-sum(a))/max(sum(a),1):+.1f}%)")
more = sum(1 for x, y in zip(a, b) if y > x)
less = sum(1 for x, y in zip(a, b) if y < x)
print(f"  -> 变多的页 {more}, 变少的页 {less}, 不变的页 {len(a)-more-less}")
print("  （若总数暴涨或大量页从 0 变多, 说明有短下划线被误当延音杠 ✗）")
