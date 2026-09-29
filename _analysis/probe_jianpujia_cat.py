# -*- coding: utf-8 -*-
"""探针: jianpujia 分类页现在的真实结构(分类页爬虫只收到 9 条, 怀疑站点改版)。

只读, 不写任何数据。用法: py -3.13 _analysis/probe_jianpujia_cat.py [分类id]
"""
import re
import ssl
import sys
import urllib.request

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()
BASE = "http://www.jianpujia.com"
CAT = sys.argv[1] if len(sys.argv) > 1 else "388"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=35, context=CTX) as r:
        return r.read().decode("utf-8", "replace")


for page in (0, 1, 2, 7):
    url = f"{BASE}/list/{CAT}-{page}.html"
    try:
        h = fetch(url)
    except Exception as e:
        print(f"[{page}] 取不到: {e}")
        continue
    i = h.find('class="mainl"')
    j = h.find("<!--@ mainl-->", i)
    ml = h[i:j if j > i else len(h)]
    print(f"--- page {page}: 全文 {len(h)} 字符, mainl 段 {len(ml)} 字符 "
          f"(mainl 起={i}, 止={j})")
    for pat, name in (
        (r'href="(/jianpu/(\d+)\.html)"', "/jianpu/<id>.html"),
        (r'href="(/pu/[^"]+)"', "/pu/..."),
        (r'href="(/\w+/(\d+)\.html)"', "/<word>/<id>.html"),
        (r'class="[^"]*(?:item|list|tit)[^"]*"', "class=*item/list/tit*"),
    ):
        m = re.findall(pat, ml)
        print(f"    {name:<22} {len(m)} 个  例: {m[:3]}")
    # 分类页每页到底有多少条? 看所有 <a ...>标题</a>
    links = re.findall(r'<a[^>]+href="([^"]+)"[^>]*>([^<]{2,60})</a>', ml)
    print(f"    mainl 内全部 a 标签: {len(links)} 个")
    for u, t in links[:8]:
        print(f"        {t.strip()[:40]:<42} {u}")
    tail = re.findall(r'/list/%s-(\d+)\.html' % CAT, h)
    print(f"    分页链接号(全文): {sorted(set(int(x) for x in tail))[-6:] if tail else '无'}")
