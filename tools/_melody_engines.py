# -*- coding: utf-8 -*-
"""用 Parsons 轮廓码试两个公开旋律检索库(Musipedia / MelodyCatcher)。"""
import re
import ssl
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()
PC = "*URDUDRURDUD"


def get(u, data=None):
    h = {"User-Agent": UA, "Accept-Language": "en,zh;q=0.8"}
    body = urllib.parse.urlencode(data).encode() if data else None
    if body:
        h["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(u, data=body, headers=h)
    with urllib.request.urlopen(req, timeout=25, context=CTX) as r:
        return r.status, r.read().decode("utf-8", "replace"), r.geturl()


TRIES = [
    ("musipedia 首页", "https://www.musipedia.org/", None),
    ("musipedia parsons(GET)",
     "https://www.musipedia.org/result.html?tx_mpsearch_pi1%5Bpc%5D=" + urllib.parse.quote(PC) +
     "&tx_mpsearch_pi1%5Bsubmit_button%5D=Search", None),
    ("melodycatcher 首页", "https://www.melodycatcher.com/", None),
    ("melodycatcher 查询",
     "https://www.melodycatcher.com/search?q=" + urllib.parse.quote("3 6 6 5 6 3 3 7 7 6 7 3"), None),
]
for lab, u, data in TRIES:
    try:
        st, h, fin = get(u, data)
    except Exception as e:
        print(f"  {lab:<24} 失败 {type(e).__name__}")
        continue
    t = re.search(r"<title>(.*?)</title>", h, re.S)
    print(f"  {lab:<24} {st} {len(h):>7}B  标题={(t.group(1).strip()[:44] if t else '?')}")
    links = [x.strip() for x in re.findall(r"<a[^>]*>([^<>{}]{4,60})</a>", h)]
    if links:
        print("      链接样本: " + " | ".join(links[:8]))
