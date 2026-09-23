# -*- coding: utf-8 -*-
"""直接试 qupu123 的拼音别名网址(黑色柳丁=heseliuding.html 就是这么找到的), 给最后的缺口找谱。"""
import io
import os
import re
import sys
import urllib.parse
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
BASE = "https://www.qupu123.com"


def get(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("utf-8", "replace"), r.status


# 候选题 -> 可能的拼音别名
CAND = {
    "大国民": ["daguomin", "daguom?", "daguominge"],
    "志明与春娇": ["zhimingyuchunjiao"],
    "双截棍": ["shuangjiegun", "shuangjiegum"],
    "红茶馆": ["hongchaguan"],
}
CATS = ["sanzi", "sizi", "wuzi", "liuzi", "qizi", "bazi"]
found = {}
for title, slugs in CAND.items():
    for cat in CATS:
        for sl in slugs:
            if "?" in sl:
                continue
            u = f"{BASE}/tongsu/{cat}/{sl}.html"
            try:
                h, st = get(u)
            except Exception:
                continue
            tt = re.search(r"<title>(.*?)</title>", h, re.S)
            t = tt.group(1).strip() if tt else "?"
            if title in t or title in h[:4000]:
                imgs = [x for x in re.findall(r'<img[^>]+src="([^"]+)"', h, re.I)
                        if re.search(r"/(?:Public/Uploads|data2/uploads)/", x)]
                print(f"  命中 {title}  ->  {u}")
                print(f"       标题 {t[:44]}  可取图 {len(imgs)} 张")
                found.setdefault(title, []).append((u, len(imgs)))
    if title not in found:
        print(f"  {title}: 拼音别名未命中")

print("\n合计:", {k: len(v) for k, v in found.items()})
