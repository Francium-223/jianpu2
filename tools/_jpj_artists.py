# -*- coding: utf-8 -*-
"""把 jianpujia 站点地图里的 85 个 /list/<id> 索引页全挖出来(名字 -> id), 供定向爬歌手页用。"""
import io
import os
import re
import ssl
import sys
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "http://www.jianpujia.com/"})
    with urllib.request.urlopen(req, timeout=30, context=CTX) as r:
        return r.read().decode("utf-8", "replace")


h = fetch("http://www.jianpujia.com/sitemap.html")
pairs = re.findall(r'href="https://www\.jianpujia\.com/list/(\d+)-\d+\.html"[^>]*>([^<]{1,30})<', h)
seen = {}
for i, n in pairs:
    seen.setdefault(i, n.strip())
print(f"索引页 {len(seen)} 个\n")
with io.open("train-work/jianpujia_artists.tsv", "w", encoding="utf-8") as f:
    for i, n in sorted(seen.items(), key=lambda x: int(x[0])):
        f.write(f"{n}\t{i}\n")
        print(f"  {n:<16} {i}")
