# -*- coding: utf-8 -*-
"""直接调底层转写(batch_transcribe.pick_page + transcribe_paged), 绕开 transcribe_source.py。

为什么另写: `transcribe_source.py` 在这种刚爬下来的目录上会列不出谱(它以某个基准列目录,
实测对 images-prep/qupu123-search 报 "0 个谱"), 但底层 pick_page 手动调是好的。
本脚本对每个子目录: pick_page -> is_impure 检查 -> transcribe_paged -> 写 batch-out/<name>.txt。

用法: py -3.13 tools/transcribe_dirs.py images-prep/qupu123-search [--limit N]
"""
import argparse
import glob
import os
import sys
import time

os.chdir(r"D:\Documents_D\jianpu2")
sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT  # noqa: E402
import jp_transcribe as JP  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("--limit", type=int, default=0)
ap.add_argument("--maxh", type=int, default=20000)   # 超长图由 split_pages 切, 这里只挡病态图
a = ap.parse_args()

OUT = "batch-out"
os.makedirs(OUT, exist_ok=True)
dirs = sorted(d for d in glob.glob(os.path.join(a.src, "*")) if os.path.isdir(d))
if a.limit:
    dirs = dirs[:a.limit]
have = {os.path.basename(f)[:-4] for f in glob.glob(OUT + "/*.txt")}

ok = empt = skip = fail = 0
for i, d in enumerate(dirs, 1):
    name = BT.safe_name(os.path.basename(d))
    if name in have:
        continue
    txt, png = f"{OUT}/{name}.txt", f"{OUT}/{name}.png"
    page = BT.pick_page(d)
    if not page:
        print(f"[{i}/{len(dirs)}] {name[:44]}: 无谱页图", flush=True)
        skip += 1
        continue
    t0 = time.time()
    try:
        blocked = JP.is_impure(page)
    except Exception:
        blocked = False
    try:
        toks, _meta = BT.transcribe_paged(page, txt, png)
    except Exception as ex:
        print(f"[{i}/{len(dirs)}] {name[:44]}: 失败 {type(ex).__name__} {str(ex)[:50]}", flush=True)
        fail += 1
        continue
    if blocked:
        if os.path.exists(png):
            os.remove(png)
        print(f"[{i}/{len(dirs)}] {name[:44]}: 非纯简谱, 跳过 ({time.time()-t0:.0f}s)", flush=True)
        skip += 1
        continue
    with open(txt, "w", encoding="utf-8") as f:
        f.write(" ".join(toks))
    nd = sum(1 for t in toks if t.lstrip("qsdh,").rstrip("'.") and t.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    print(f"[{i}/{len(dirs)}] {name[:44]}: token {len(toks)} 数字 {nd} ({time.time()-t0:.0f}s)", flush=True)
    ok += 1 if nd else 0
    empt += 0 if nd else 1

print(f"\n完成: 有数字 {ok} / 转出空 {empt} / 非纯简谱 {skip} / 失败 {fail}", flush=True)
