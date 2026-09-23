# -*- coding: utf-8 -*-
"""探测各曲谱站的搜索接口(为批量抓热门歌简谱做准备)。"""
import re, sys, urllib.parse, urllib.request
sys.stdout.reconfigure(encoding="utf-8")

HDR = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                     "(KHTML, like Gecko) Chrome/122.0 Safari/537.36"}
KW = "跳楼机"

TESTS = [
    ("jianpujia", "https://www.jianpujia.com/search?keyword="),
    ("jianpujia-e", "https://www.jianpujia.com/e/search/?searchget=1&tbname=news&keyboard="),
    ("cnjpw", "https://www.cnjpw.net/search.php?keyword="),
    ("cnjpw2", "https://www.cnjpw.net/e/search/?keyboard="),
    ("jianpu.net", "https://www.jianpu.net/search.php?keyword="),
    ("qupu123", "https://www.qupu123.com/search.php?keyword="),
    ("qinpu123", "https://www.qinpu123.com/search.php?keyword="),
    ("kanyuepu", "https://www.kanyuepu.com/search?q="),
]

for name, base in TESTS:
    url = base + urllib.parse.quote(KW)
    try:
        req = urllib.request.Request(url, headers=HDR)
        r = urllib.request.urlopen(req, timeout=15)
        h = r.read().decode("utf-8", "ignore")
        links = re.findall(r'href="([^"]*\.html)"', h)
        score_links = [l for l in links if ("pu" in l.lower() or "jianpu" in l.lower())]
        print(f"{name:12s} {r.status}  {len(h):7d}B  链接={len(links):4d} 曲谱类={len(set(score_links))}")
        for s in list(dict.fromkeys(score_links))[:3]:
            print(f"               {s[:90]}")
    except Exception as e:
        print(f"{name:12s} {type(e).__name__}: {str(e)[:50]}")
