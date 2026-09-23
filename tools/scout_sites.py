# -*- coding: utf-8 -*-
"""简谱源侦察器: 对候选站点各抓一张真实曲谱图, 量分辨率并排名。

对每个站: 取首页 -> 找"像曲谱页"的链接 -> 打开 -> 取最大的图 -> 量宽高。
输出: train-work/source_scout.tsv
"""
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
from PIL import Image

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

SITES = [
    ("jianpujia", "http://www.jianpujia.com/"),
    ("qupu123", "https://www.qupu123.com/"),
    ("jianpucn", "http://www.jianpu.cn/"),
    ("zhaogepu", "http://www.zhaogepu.com/"),
    ("5haoku", "https://www.5haoku.com/"),
    ("fysongs", "http://www.fysongs.cn/"),
    ("soopu", "http://www.soopu.cn/"),
    ("gepu123", "http://www.gepu123.com/"),
    ("jianpu8", "http://www.jianpu8.com/"),
    ("yuepu123", "http://www.yuepu123.com/"),
    ("gqpu", "http://www.gqpu.com/"),
    ("91pu", "https://www.91pu.com.tw/"),
    ("jianpuku", "http://www.jianpuku.com/"),
    ("yipu", "http://www.yipu.com.cn/"),
]


def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    for enc in ("utf-8", "gbk"):
        try:
            return raw.decode(enc)
        except Exception:
            pass
    return raw.decode("utf-8", errors="replace")


def probe(name, home):
    """返回 (状态, 样本宽, 样本高, KB, 来源URL)"""
    try:
        h = fetch(home)
    except Exception as e:
        return ("打不开", 0, 0, 0, type(e).__name__)
    # 找曲谱详情页链接(带数字 id 的 .html, 排除首页/列表)
    links = re.findall(r'href="((?:https?://[^"]+|/[^"]*?)\d{3,}\.html)"', h)
    seen = []
    for l in links:
        if l.startswith("/"):
            l = urllib.parse.urljoin(home, l)
        if l not in seen:
            seen.append(l)
    for l in seen[:6]:
        try:
            ph = fetch(l)
        except Exception:
            continue
        imgs = re.findall(r'<img[^>]+src="((?:https?:)?//[^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
        imgs = [i for i in imgs if not re.search(r"logo|ico|banner|ad[_\-]|qrcode", i, re.I)]
        best = None
        for iu in imgs[:6]:
            full = iu if iu.startswith("http") else "http:" + iu
            try:
                req = urllib.request.Request(full, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=15) as r:
                    data = r.read()
            except Exception:
                continue
            p = "train-work/_scout.bin"
            open(p, "wb").write(data)
            try:
                im = Image.open(p)
                a = im.width * im.height
            except Exception:
                continue
            if best is None or a > best[0]:
                best = (a, im.width, im.height, len(data) // 1024, full)
        if best:
            return ("OK", best[1], best[2], best[3], best[4])
    return ("无图", 0, 0, 0, "")


rows = []
print(f"{'站':<12}{'状态':<8}{'样本宽':>7}{'样本高':>7}{'KB':>6}")
print("-" * 44)
for name, home in SITES:
    st, w, hh, kb, src = probe(name, home)
    print(f"{name:<12}{st:<8}{w:>7}{hh:>7}{kb:>6}")
    rows.append((name, st, w, hh, kb, src))
    time.sleep(0.3)

with io.open("train-work/source_scout.tsv", "w", encoding="utf-8") as g:
    g.write("site\tstatus\twidth\theight\tkb\turl\n")
    for r in rows:
        g.write("\t".join(str(x) for x in r) + "\n")

ok = [r for r in rows if r[1] == "OK"]
print("\n按样本宽度排名:")
for name, st, w, hh, kb, src in sorted(ok, key=lambda x: -x[2]):
    print(f"   {name:<12}{w:>5}x{hh:<5} {kb:>4}KB   {src[:60]}")
