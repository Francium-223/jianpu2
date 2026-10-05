# -*- coding: utf-8 -*-
"""枚举 qupu123 一级栏目及其自报条目数(算账分母)。只读。"""
import re
import sys
import time
import urllib.request
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def g(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA,
                                             "Referer": "https://www.qupu123.com/"})
    with tlsfetch.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


h = g("https://www.qupu123.com/")
navs = re.findall(r'<a[^>]+href="(/([a-z0-9_]+)/)"[^>]*>([^<]{1,26})</a>', h)
cnt = Counter()
label = {}
for href, slug, text in navs:
    cnt[slug] += 1
    label.setdefault(slug, text.strip())
print("首页一级栏目 %d 个:" % len(cnt))
for slug, n in cnt.most_common():
    print("  /%-14s x%-3d %s" % (slug + "/", n, label.get(slug, "")))

print("\n各栏目页自报条目数:")
total = 0
for slug in cnt:
    u = "https://www.qupu123.com/%s/" % slug
    try:
        t = g(u)
    except Exception as e:
        print("  /%-14s 失败 %s" % (slug + "/", type(e).__name__))
        continue
    m = re.search(r"共\s*([\d,]+)\s*([条张首份])", t)
    pages = re.search(r"([\d,]+)\s*页", t)
    n = int(m.group(1).replace(",", "")) if m else None
    if n:
        total += n
    print("  /%-14s 自报 %-8s %s · %s 页" % (
        slug + "/", n if n is not None else "无", m.group(2) if m else "", pages.group(1) if pages else "?"))
    time.sleep(1.1)
print("  合计自报: %d" % total)
