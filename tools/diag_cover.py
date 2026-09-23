# -*- coding: utf-8 -*-
"""打印 token 的行分布: 每行带切出多少个块, 哪些行被丢。"""
import glob, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import jp_transcribe as JP
import transcribe as T

page = glob.glob("images-prep/jianpujia-crawl/*74580/*.jpg")[0]
toks, meta = JP.render(page, "train-work/_tmp2.png")
arr = np.asarray(Image.open(page).convert("L"))
content = arr < T.TOL

# 按 band 分组统计
from collections import Counter
cnt = Counter()
for t, m in zip(toks, meta):
    cnt[m["band"]] += 1
print("token 按行带分布:")
for b in sorted(cnt):
    print(f"  band y={b:4d}: {cnt[b]:3d} 个 token")

print(f"\n总 token {len(toks)}")
print("\n各 band 的切块情况:")
bands = []
for s0, e0 in T.fine_rows(content, T.ROW_GAP):
    bands += T.split_row_inner(content, s0, e0)
for s, e in bands:
    sub = content[s:e + 1]
    st, hl = T.strip_hlines(sub)
    cs = [c for c in T.components(st) if 10 <= c[5] <= 50 and c[4] >= 4]
    frac = (sum(1 for c in cs if c[5] >= 1.4 * c[4]) / len(cs)) if cs else 0.0
    if frac < 0.85:
        continue
    regs = T.crop_note_regions(sub)
    print(f"  行带 y[{s},{e}] h={e-s+1:3d} frac={frac:.2f}  切出块={len(regs):3d}  token={cnt.get(s,0):3d}")
