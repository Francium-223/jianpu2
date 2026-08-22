# -*- coding: utf-8 -*-
"""Probe script: inspect jianpujia.com (简谱之家) page structure."""
import re
import ssl
import sys
import urllib.request

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}


def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=20, context=ctx).read()


def show(url, pattern, label="", n=2500, offset=0):
    html = fetch(url).decode("utf-8", "ignore")
    print(f"=== {label or url} len={len(html)}")
    i = html.find(pattern)
    if i < 0:
        print("pattern not found; head:", html[:300])
        return
    print(html[max(0, i - offset): i + n])
    print()


def links(url, pat=r'href="(/[a-z]+/[^"]+\.html)"'):
    html = fetch(url).decode("utf-8", "ignore")
    found = sorted(set(re.findall(pat, html)))
    print(f"=== links on {url} ({len(found)})")
    for l in found[:60]:
        print(l)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "show"
    url = sys.argv[2] if len(sys.argv) > 2 else "https://www.jianpujia.com/"
    if mode == "links":
        links(url)
    else:
        pat = sys.argv[3] if len(sys.argv) > 3 else "list"
        show(url, pat)
