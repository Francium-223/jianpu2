# -*- coding: utf-8 -*-
"""在 qupu123 上找《夜曲》(周杰伦), 列出结果并探每条的图片分辨率。"""
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


def get(u, binary=False, t=30):
    r = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": "https://www.qupu123.com/"})
    with urllib.request.urlopen(r, timeout=t) as x:
        return x.read() if binary else x.read().decode("utf-8", "replace")


for kw in ["夜曲 周杰伦", "周杰伦 夜曲"]:
    print(f"\n{'='*56}\n检索: {kw}")
    try:
        h = get("https://www.qupu123.com/Search?keys=" + urllib.parse.quote(kw))
    except Exception as e:
        print("  失败", e)
        continue
    links = re.findall(r'href="(/[^"]+?/p(\d+)\.html)"[^>]*>([^<]{2,90})</a>', h)
    hit = [(u, i, t.strip()) for u, i, t in links if "夜曲" in t]
    print(f"  共 {len(links)} 条, 含'夜曲' {len(hit)} 条:")
    for u, i, t in hit[:8]:
        try:
            ph = get("https://www.qupu123.com" + u)
        except Exception:
            print(f"    {u:40s} {t[:34]}  页面打不开")
            continue
        imgs = [urllib.parse.urljoin("https://www.qupu123.com/", x)
                for x in re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)]
        imgs = [x for x in dict.fromkeys(imgs) if "/Public/Uploads/" in x]
        dims = []
        for iu in imgs[:3]:
            try:
                data = get(iu, binary=True, t=20)
                open("train-work/_yq.bin", "wb").write(data)
                im = Image.open("train-work/_yq.bin")
                if im.width >= 500:
                    dims.append(f"{im.width}x{im.height}")
            except Exception:
                pass
        print(f"    {u:40s} {t[:32]:34s} {dims}")
