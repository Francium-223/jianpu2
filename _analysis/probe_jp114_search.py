# -*- coding: utf-8 -*-
"""探针: jp114.com(简谱库) 的搜索接口对**榜单缺口曲**有没有货。

站点形态(2026-09-29 实测):
  * 搜索 `GET /search.html?key=<关键词>` —— 返回结果里有 `href="/jianpu/<id>.html"`;
    页面上还有 4 条**固定侧栏**(苹果香/保卫黄河/后来吉他谱/爱人错过吉他谱), 要剔掉。
  * 曲谱页 `/jianpu/<id>.html`: `<title>` 是"曲名简谱,…_分类简谱_简谱库", 谱图在
    `imgs.92kk.com/attachment/jianpu/...`(独立图床)。

只读, 不下载图片。用法: py -3.13 _analysis/probe_jp114_search.py 曲名1 曲名2 ...
"""
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()
BASE = "https://www.jp114.com"
SIDEBAR = {"615488", "654730", "1565158", "1565970"}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=30, context=CTX) as r:
        return r.read().decode("utf-8", "replace")


def search(key):
    h = fetch(f"{BASE}/search.html?key={urllib.parse.quote(key)}")
    out = []
    for m in re.finditer(r'href="(/jianpu/(\d+)\.html)"[^>]*>([^<]{2,90})', h):
        path, sid, txt = m.group(1), m.group(2), m.group(3).strip()
        if sid in SIDEBAR or not txt:
            continue
        out.append((sid, txt, path))
    # 去重保序
    seen, uniq = set(), []
    for sid, txt, path in out:
        if sid in seen:
            continue
        seen.add(sid)
        uniq.append((sid, txt, path))
    return uniq


for key in sys.argv[1:]:
    try:
        hits = search(key)
    except Exception as e:
        print(f"{key}: 搜索失败 {type(e).__name__} {e}")
        continue
    print(f"{key}: 命中 {len(hits)} 条")
    for sid, txt, path in hits[:5]:
        print(f"    {txt[:56]:<58} {path}")
    if hits:
        # 看第一条详情页: 标题 + 图片数
        try:
            d = fetch(BASE + hits[0][2])
            t = re.search(r"<title>([^<]*)</title>", d)
            imgs = re.findall(r'<img[^>]+src="((?:https?:)?//imgs\.92kk\.com/[^"]+)"', d)
            print(f"    详情: {(t.group(1) if t else '?')[:70]}")
            print(f"    谱图 {len(imgs)} 张  例: {imgs[0] if imgs else '无'}")
        except Exception as e:
            print(f"    详情失败 {type(e).__name__}")
    time.sleep(0.6)
