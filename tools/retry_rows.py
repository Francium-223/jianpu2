# -*- coding: utf-8 -*-
"""重跑"fine_rows 行带划分失败(<=2)"的谱 —— 用修好后的阈值重新转写。断点续传。"""
import glob, os, sys, time, traceback
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
from batch_transcribe import pick_page, transcribe_paged

OUT = "batch-out"
MAX_H = int(os.environ.get("JP_MAX_H", "3000"))

# 1. 找出划分失败的目录
bad_dirs = []
for d in glob.glob("images-prep/*/*/"):
    page = pick_page(d)
    if not page:
        continue
    try:
        arr = np.asarray(Image.open(page).convert("L"))
        content = arr < T.TOL
        if len(T.fine_rows(content, T.ROW_GAP)) <= 2:
            bad_dirs.append(d)
    except Exception:
        continue
print(f"划分失败的谱: {len(bad_dirs)} 个", flush=True)

done = skip = fail = 0
for i, d in enumerate(bad_dirs):
    name = os.path.basename(os.path.normpath(d))
    txt = f"{OUT}/{name}.txt"
    png = f"{OUT}/{name}.png"
    if os.path.exists(txt):
        done += 1
        continue
    page = pick_page(d)
    try:
        _w, _h = Image.open(page).size
    except Exception:
        _h = 0
    if _h > MAX_H:
        skip += 1
        print(f"[{i+1}/{len(bad_dirs)}] 跳过超高 {name[:34]}", flush=True)
        continue
    t0 = time.time()
    try:
        toks, meta = transcribe_paged(page, txt, png)
        open(txt, "w", encoding="utf-8").write(" ".join(toks))
        print(f"[{i+1}/{len(bad_dirs)}] {name[:40]}: 音{len(toks)} ({time.time()-t0:.0f}s)", flush=True)
    except Exception as ex:
        fail += 1
        print(f"[{i+1}/{len(bad_dirs)}] {name[:40]}: 失败 {type(ex).__name__}", flush=True)
print(f"\n完成: 已有{done} 跳过{skip} 失败{fail}", flush=True)
