# -*- coding: utf-8 -*-
"""测 B站 搜索 API 能否拿到播放量(用于给谱图按热度排序)。"""
import json, sys, urllib.parse, urllib.request
sys.stdout.reconfigure(encoding="utf-8")

HDR = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/122.0 Safari/537.36",
    "Referer": "https://www.bilibili.com/",
    "Accept": "application/json, text/plain, */*",
    "Cookie": "buvid3=%s-infoc; b_nut=1700000000" % __import__("uuid").uuid4(),
}

def search(keyword, page=1):
    url = ("https://api.bilibili.com/x/web-interface/search/type?"
           + urllib.parse.urlencode({"search_type": "video", "keyword": keyword, "page": page}))
    req = urllib.request.Request(url, headers=HDR)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)

for kw in ["春天在哪里", "小星星"]:
    try:
        d = search(kw)
        print(f"\n=== {kw}  code={d.get('code')} msg={d.get('message')}")
        res = (d.get("data") or {}).get("result") or []
        print(f"  命中 {len(res)} 个视频")
        for v in res[:5]:
            title = re.sub(r"<[^>]+>", "", v.get("title", "")) if (re := __import__("re")) else v.get("title")
            print(f"    play={v.get('play'):>9}  {title[:40]}  @{v.get('author','')}")
    except Exception as ex:
        print(f"\n=== {kw} 失败: {type(ex).__name__} {str(ex)[:80]}")
