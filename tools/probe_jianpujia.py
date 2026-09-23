# -*- coding: utf-8 -*-
"""验证 jianpujia 的歌手页: 列出周杰伦的曲谱, 抓一页看图片真实分辨率。"""
import io
import os
import re
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(url, enc="gbk"):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        raw = r.read()
    return raw.decode(enc, errors="replace")


# 1) 全部分类(含歌手)
home = get("http://www.jianpujia.com/")
cats = re.findall(r'href="(/list/\d+-0\.html)"[^>]*>([^<]{2,30})', home)
print(f"首页分类 {len(cats)} 个:")
for u, t in cats:
    print(f"   {u:24s} {t.strip()}")

# 2) 周杰伦页
url = "http://www.jianpujia.com/list/583-0.html"
h = get(url)
items = re.findall(r'href="(/[a-z]+/\d+\.html)"[^>]*>([^<]{2,70})', h)
print(f"\n周杰伦页曲谱链接 {len(items)} 个:")
for u, t in items[:8]:
    print(f"   {u}  {t.strip()[:50]}")

# 3) 抓第一个曲谱页, 找图片 + 量分辨率
if items:
    purl = "http://www.jianpujia.com" + items[0][0]
    ph = get(purl)
    imgs = re.findall(r'<img[^>]+src="((?:https?:)?//[^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
    imgs = [i for i in imgs if "logo" not in i.lower() and "ico" not in i.lower()]
    print(f"\n曲谱页 {purl}")
    print(f"  图片 {len(imgs)} 张:")
    from PIL import Image
    for i, iu in enumerate(imgs[:4]):
        full = iu if iu.startswith("http") else "http:" + iu
        try:
            req = urllib.request.Request(full, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r:
                data = r.read()
            p = f"train-work/_probe_{i}.jpg"
            open(p, "wb").write(data)
            im = Image.open(p)
            print(f"   {im.size[0]}x{im.size[1]}  {len(data)//1024} KB  {full[:78]}")
        except Exception as e:
            print(f"   失败 {type(e).__name__} {full[:60]}")
