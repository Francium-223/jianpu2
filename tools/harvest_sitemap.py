# -*- coding: utf-8 -*-
"""把各站 sitemap 拉下来, 建"站点id -> 页面URL"索引(一次请求顶几千次试探)。

qupu123 实测有 /sitemap.xml (3.1MB, `<loc>http://www.qupu123.com/<root>/p<id>.html</loc>`)。
jianpujia / jianpu.cn 也顺带试一下; 没有就跳过。
产物: train-work/site_url_index.tsv   (source<TAB>URL<TAB>来源)
"""
import io
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
OUT = "train-work/site_url_index.tsv"

CAND = [
    ("qupu123", "https://www.qupu123.com/sitemap.xml"),
    ("jianpujia", "https://www.jianpujia.com/sitemap.xml"),
    ("jianpucn", "http://www.jianpu.cn/sitemap.xml"),
]


def fetch(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60, context=CTX) as r:
        return r.read()


idx = {}
for site, u in CAND:
    try:
        b = fetch(u)
    except urllib.error.HTTPError as e:
        print(f"{site}: HTTP {e.code}  {u}")
        continue
    except Exception as e:
        print(f"{site}: ERR {type(e).__name__}  {u}")
        continue
    t = b.decode("utf-8", "replace")
    locs = re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", t)
    n = 0
    for loc in locs:
        m = re.search(r"p(\d+)\.html$", loc) if site == "qupu123" else re.search(r"/(\d+)\.htm$", loc)
        if m:
            key = site + "-" + m.group(1)
            if key not in idx:
                idx[key] = loc
                n += 1
    print(f"{site}: {len(b)} 字节, {len(locs)} 条 loc, 收下 {n} 条 id->URL")
    time.sleep(0.5)

with io.open(OUT, "w", encoding="utf-8", newline="\n") as g:
    g.write("source\turl\t来源\n")
    for k, v in sorted(idx.items()):
        g.write(f"{k}\t{v}\tsitemap\n")
print(f"合计 {len(idx)} 条 -> {OUT}")
