# -*- coding: utf-8 -*-
"""按"华语金曲清单缺口"定向爬 qupu123 —— 只爬缺的歌, 不做泛搜。

输入: train-work/mandopop_missing.txt  (歌名<TAB>歌手)
输出: images-prep/qupu123-mpNNN/  + train-work/mandopop_crawl.tsv (每首抓到几张)
可续跑: mandopop_crawl.tsv 里已有记录的歌跳过(加 --redo 重爬)。

用法: py -3.13 tools/crawl_missing_mandopop.py [每首最多几张=4] [最多几首=999]
"""
import io
import os
import subprocess
import sys
import time

import os as _os
# 2026-09-24: 原来硬编码 Windows 路径 D:\Documents_D\jianpu2, 换机器必崩。
# 与其它 tools 一致: 自己 chdir 到仓库根(jianpu2/)。
_os.chdir(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
PY = sys.executable
PER = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 4
CAP = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 999
# --redo: 忽略日志重爬(修了爬虫 bug 之后要重跑零结果的那些)
# --only a,b,c: 只跑指定歌名
REDO = "--redo" in sys.argv
ONLY = None
if "--only" in sys.argv:
    ONLY = {x.strip() for x in sys.argv[sys.argv.index("--only") + 1].split(",") if x.strip()}
ONLY_FILE = sys.argv[sys.argv.index("--only-file") + 1] if "--only-file" in sys.argv else None

LOG = "train-work/mandopop_crawl.tsv"
done = set()
if os.path.exists(LOG):
    for line in io.open(LOG, encoding="utf-8"):
        c = line.rstrip("\n").split("\t")
        if c and c[0]:
            done.add(c[0])
if ONLY_FILE:
    ONLY = {l.split("\t")[0].strip() for l in io.open(ONLY_FILE, encoding="utf-8") if l.strip()}

titles = []
for line in io.open("train-work/mandopop_missing.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip():
        continue
    p = line.split("\t")
    t = p[0].strip()
    if ONLY is not None and t not in ONLY:
        continue
    if t in done and not REDO:
        continue
    titles.append((t, p[1].strip() if len(p) > 1 else ""))
titles = titles[:CAP]
print(f"待爬 {len(titles)} 首 (日志已有 {len(done)}, redo={REDO}), 每首最多 {PER} 张\n", flush=True)

log = io.open(LOG, "a", encoding="utf-8")
tot = 0
for k, (title, artist) in enumerate(titles, 1):
    # redo 用 mp9xx 前缀, 避免撞上首轮已建的目录(爬虫对已存在且非空的目录会跳过)
    slug = f"mp9{k:03d}" if REDO else f"mp{k:03d}"
    t0 = time.time()
    try:
        r = subprocess.run([PY, "tools/crawl_qupu123.py", title, str(PER), slug],
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=300)
        out = (r.stdout or "") + (r.stderr or "")
        n = 0
        for l in out.splitlines():
            if l.startswith("完成: "):
                n = int(l.split()[1])
        msg = ""
        for l in out.splitlines():
            if l.startswith("  检索第") or l.startswith(f"{title}:"):
                msg = l.strip()
    except Exception as e:
        n, msg = -1, f"异常 {type(e).__name__}"
    print(f"[{k}/{len(titles)}] {title:<16} {artist:<10} 抓到 {n} 张  ({time.time()-t0:.0f}s)"
          + (f"  | {msg[:60]}" if msg else ""), flush=True)
    log.write(f"{title}\t{artist}\t{n}\t{slug}\n")
    log.flush()
    tot += max(n, 0)

print(f"\n完成: 共 {tot} 张 -> images-prep/qupu123-mp*/, 记录 {LOG}")
