# -*- coding: utf-8 -*-
"""调试 qupu123 曲谱页的图片提取。"""
import re
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(u, binary=False, t=30):
    r = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": "https://www.qupu123.com/"})
    with urllib.request.urlopen(r, timeout=t) as x:
        return x.read() if binary else x.read().decode("utf-8", "replace")


h = get("https://www.qupu123.com/Search?keys=" + urllib.parse.quote("周杰伦") + "&page=1")
m = re.findall(r'href="(/[^"]+?/p(\d+)\.html)"[^>]*>([^<]{2,90})</a>', h)
print(f"检索到 {len(m)} 条")
u, pid, title = m[0]
print(f"第一个: {u}  |{title[:40]}|")
try:
    ph = get("https://www.qupu123.com" + u)
    print(f"页面长度 {len(ph)}")
    imgs = re.findall(r'<img[^>]+src="([^"]+)"', ph, re.I)
    print("所有 img src:")
    for x in imgs[:12]:
        print("   ", x[:110])
    spec = re.findall(r'(https://www\.qupu123\.com/Public/Uploads/[^"\')\s]+)', ph)
    print(f"\n匹配 Uploads 的 {len(spec)}:")
    for x in spec[:6]:
        print("   ", x[:110])
except Exception as e:
    print("页面失败:", type(e).__name__, e)
