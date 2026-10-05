# -*- coding: utf-8 -*-
"""看 qupu123 首页导航的原始 HTML 形态。只读。"""
import re
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
req = urllib.request.Request("https://www.qupu123.com/",
                             headers={"User-Agent": UA, "Referer": "https://www.qupu123.com/"})
with tlsfetch.urlopen(req, timeout=30) as r:
    h = r.read().decode("utf-8", "replace")

i = h.find("曲谱")
print("=== 首页里所有 <a> 的 href(去重, 前 120) ===")
hrefs = re.findall(r"<a[^>]*?href=['\"]([^'\"]+)['\"][^>]*>(.*?)</a>", h, re.S)
seen = set()
shown = 0
for href, text in hrefs:
    t = re.sub(r"<[^>]+>|\s+|&nbsp;", " ", text).strip()
    if (href, t) in seen:
        continue
    seen.add((href, t))
    if href.startswith("/") and len(t) <= 20:
        print("  %-40s %s" % (href, t))
        shown += 1
    if shown > 120:
        break
print("\n=== 导航区块原文(找 'navigation'/'nav'/'menu') ===")
for kw in ("nav", "menu", "Nav"):
    j = h.find(kw)
    if j > 0:
        print("[%s] %r" % (kw, h[max(0, j - 200):j + 900]))
        break
