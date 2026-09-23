# -*- coding: utf-8 -*-
"""A) qupu123 结构勘察: 从检索结果里挑出"简谱类"曲谱页, 探它的图片地址与分辨率。"""
import os
import re
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu2")
from PIL import Image

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(url, binary=False, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "https://www.qupu123.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


h = get("https://www.qupu123.com/Search?keys=" + urllib.parse.quote("周杰伦"))
links = re.findall(r'href="(/[^"]+?\.html)"[^>]*>([^<]{0,80})</a>', h)
print(f"检索'周杰伦' 共 {len(links)} 条")
from collections import Counter
pref = Counter("/".join(u.strip("/").split("/")[:-1]) for u, _ in links)
print("路径分布:", dict(pref.most_common(8)))

# 标题含简谱字样 或 路径在 tongsu/puyou 下
cands = [(u, t.strip()) for u, t in links
         if ("简谱" in t) or u.startswith(("/tongsu/", "/puyou/"))]
print(f"\n候选(简谱/通俗) {len(cands)} 条:")
for u, t in cands[:10]:
    print(f"   {u:44s} {t[:44]}")

# 探第一个候选页
for u, t in cands[:4]:
    url = "https://www.qupu123.com" + u
    try:
        ph = get(url)
    except Exception as e:
        print(f"\n{u} 打不开 {type(e).__name__}")
        continue
    imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
    imgs = [i for i in imgs if not re.search(r"logo|ico|banner|/ad|qrcode|share", i, re.I)]
    print(f"\n{u}  ({t[:36]})  图片 {len(imgs)}:")
    for k, iu in enumerate(imgs[:3]):
        full = iu if iu.startswith("http") else urllib.parse.urljoin(url, iu)
        try:
            data = get(full, binary=True, timeout=20)
            open("train-work/_qp.bin", "wb").write(data)
            im = Image.open("train-work/_qp.bin")
            print(f"   {im.size[0]}x{im.size[1]}  {len(data)//1024}KB  {full[:70]}")
        except Exception as e:
            print(f"   取图失败 {type(e).__name__} {full[:50]}")
    break
