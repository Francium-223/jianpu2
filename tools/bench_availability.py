# -*- coding: utf-8 -*-
"""基准集验谱: 对 train-work/bench_hk_top100.txt 里每首歌去曲谱站查"有没有通俗简谱",
并检查**本地库里有没有可转的页**。输出可用于宣传的"可得率"。
用法: py -3.13 tools/bench_availability.py [列表文件] [--site qupu|jianpu] [--skip-net]
产物: train-work/bench_availability.tsv  (标题, 歌手, qupu通俗数, qupu器乐数, 本地目录数, 本地已转)
"""
import glob
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LIST = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "train-work/bench_hk_top100.txt"
SKIP_NET = "--skip-net" in sys.argv
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

rows = []
for line in open(LIST, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split("|")
    rows.append((parts[0].strip(), parts[1].strip() if len(parts) > 1 else ""))


def qupu(title):
    """返回 (通俗简谱数, 器乐谱数, 吉他谱数, 总命中)。"""
    u = f"https://www.qupu123.com/Search?keys={urllib.parse.quote(title)}"
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        html = r.read().decode("utf-8", errors="replace")
    ids = set(re.findall(r'href="(/[a-z]+/[a-z0-9]*/?p\d+\.html)"', html))
    t = sum(1 for i in ids if i.startswith("/tongsu/"))
    q = sum(1 for i in ids if i.startswith("/qiyue/"))
    j = sum(1 for i in ids if i.startswith("/jipu/"))
    return t, q, j, len(ids)


# 本地库索引: 先按"曲名部分"建一次索引(16172 个目录 × 每次正则太慢), 再按曲名精确查。
imgs = [os.path.basename(d) for d in glob.glob("images-prep/*/*") if os.path.isdir(d)]
dones = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}


def _head(x):
    base = x.split("__")[0]
    return re.split(r"[（(\s　【\[《]", base)[0]


_idx = {}
for x in imgs:
    _idx.setdefault(_head(x), []).append(x)
_didx = {}
for x in dones:
    _didx.setdefault(_head(x), []).append(x)
print(f"列表 {len(rows)} 首   本地谱目录 {len(imgs)} 个(曲名索引 {len(_idx)})   已转写 {len(dones)} 份")


def local_hit(song, table):
    """按**曲名精确**匹配, 不能只做子串 —— 短歌名(《枫》《彩虹》《安静》《大海》)用子串会漫天命中。"""
    return table.get(song, []) if song else []

out = ["标题\t歌手\tqupu通俗\tqupu器乐\tqupu吉他\t本地目录\t本地已转"]
ok_site = ok_local = 0
for k, (title, artist) in enumerate(rows, 1):
    t = q = j = n = 0
    if not SKIP_NET:
        try:
            t, q, j, n = qupu(title)
        except Exception as e:
            print(f"  [{k}] {title}: 查询失败 {type(e).__name__}")
        time.sleep(0.45)
    loc = local_hit(title, _idx)
    loc_done = local_hit(title, _didx)
    if t > 0:
        ok_site += 1
    if loc or loc_done:
        ok_local += 1
    out.append(f"{title}\t{artist}\t{t}\t{q}\t{j}\t{len(loc)}\t{len(loc_done)}")
    if k % 20 == 0:
        print(f"  ...{k}/{len(rows)}  站上有谱 {ok_site}  本地有 {ok_local}", flush=True)

open("train-work/bench_availability.tsv", "w", encoding="utf-8").write("\n".join(out) + "\n")
n = len(rows)
print(f"\n=== 结果 ===")
print(f"曲谱站有通俗简谱: {ok_site}/{n} = {100.0*ok_site/n:.1f}%")
print(f"本地已有谱目录或已转写: {ok_local}/{n} = {100.0*ok_local/n:.1f}%")
no = [r[0] for r in rows if r[0] not in [o.split("\t")[0] for o in out[1:] if int(o.split("\t")[2]) > 0]]
if no:
    print(f"站上没有通俗简谱的 {len(no)} 首: {'、'.join(no[:25])}")
print("明细: train-work/bench_availability.tsv")
