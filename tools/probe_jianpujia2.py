# -*- coding: utf-8 -*-
"""正确复探 jianpujia: UTF-8 解码 + 区分 简谱/吉他谱 路径 + 量简谱图的真实分辨率。"""
import os
import re
import sys
import urllib.request
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("utf-8", errors="replace")


home = get("http://www.jianpujia.com/")
cats = re.findall(r'href="(/list/\d+-0\.html)"[^>]*>([^<]{2,30})', home)
print(f"分类 {len(cats)} 个:")
for u, t in cats:
    print(f"   {u:22s} {t.strip()}")

h = get("http://www.jianpujia.com/list/583-0.html")
items = re.findall(r'href="(/([a-z]+)/\d+\.html)"[^>]*>([^<]{2,90})', h)
pref = Counter(p for _, p, _ in items)
print(f"\n周杰伦页 {len(items)} 条, 路径前缀: {dict(pref)}")
for u, p, t in items[:14]:
    print(f"   {u:22s} {t.strip()[:56]}")

# 找简谱类路径的第一个, 探它的图片
for u, p, t in items:
    if p != "jitapu" and ("简谱" in t or p in ("jianpu", "gepu", "pu")):
        purl = "http://www.jianpujia.com" + u
        ph = get(purl)
        imgs = re.findall(r'<img[^>]+src="((?:https?:)?//[^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
        imgs = [i for i in imgs if "logo" not in i.lower() and "ico" not in i.lower()]
        print(f"\n简谱页 {purl}  ({t.strip()[:40]})")
        print(f"  图片 {len(imgs)} 张:")
        from PIL import Image
        for i, iu in enumerate(imgs[:3]):
            full = iu if iu.startswith("http") else "http:" + iu
            try:
                req = urllib.request.Request(full, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=25) as r:
                    data = r.read()
                pth = f"train-work/_jp2_{i}.jpg"
                open(pth, "wb").write(data)
                im = Image.open(pth)
                print(f"   {im.size[0]}x{im.size[1]}  {len(data)//1024} KB  {full[:76]}")
            except Exception as e:
                print(f"   失败 {type(e).__name__}")
        break
