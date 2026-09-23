# -*- coding: utf-8 -*-
"""按 train-work/artist_pages.txt 批量爬歌手页的所有曲谱。

顺序按名单来(邓丽君在最前, 优先补上)。纯网络任务, 不占 GPU。
日志: train-work/crawl_artists.log
"""
import io, os, subprocess, sys, time
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

PY = sys.executable
rows = []
for l in io.open("train-work/artist_pages.txt", encoding="utf-8"):
    p = l.strip().split("\t")
    if len(p) >= 2:
        rows.append((p[0], p[1], int(p[2]) if len(p) > 2 and p[2].isdigit() else 0))
print(f"歌手页 {len(rows)} 个")

LOG = open("train-work/crawl_artists.log", "w", encoding="utf-8")


def log(m):
    print(m, flush=True)
    LOG.write(m + "\n"); LOG.flush()


for i, (name, url, total) in enumerate(rows, 1):
    log(f"\n[{i}/{len(rows)}] {name}  (页面 {total} 首)")
    t0 = time.time()
    r = subprocess.run([PY, "tools/crawl_artist.py", url, "400"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    for l in (r.stdout or "").strip().splitlines()[-3:]:
        log("   " + l)
    log(f"   ({time.time()-t0:.0f}s)")
log("\n=== 全部歌手爬完 ===")
LOG.close()
