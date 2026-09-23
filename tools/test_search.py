# -*- coding: utf-8 -*-
"""测 jianpu.cn 搜索接口(UTF-8 编码查询)能否用。"""
import re, sys, urllib.parse, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
UA = "Mozilla/5.0"

for kw in ["陈奕迅", "富士山下", "告白气球", "周杰伦"]:
    q = urllib.parse.quote(kw.encode("utf-8"))
    u = "http://www.jianpu.cn/search?q=" + q
    try:
        req = urllib.request.Request(u, headers={"User-Agent": UA})
        h = urllib.request.urlopen(req, timeout=20).read().decode("gbk", errors="replace")
        m = re.search(r"<h1[^>]*>(.*?)</h1>", h, re.S)
        n = re.search(r"找到条\s*(\d+)", h)
        links = re.findall(r"href='(/pu/\d+/\d+\.htm)'[^>]*>\s*([^<]{1,40})", h)
        print(f"{kw}: h1={m.group(1).strip()[:30] if m else None}  命中={n.group(1) if n else '?'}  链接={len(links)}")
        for l in links[:5]:
            print("     ", l[1].strip()[:40])
    except Exception as e:
        print(kw, "失败", e)
