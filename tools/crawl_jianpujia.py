# -*- coding: utf-8 -*-
"""爬 jianpujia(简谱之家) 的曲谱。

为什么选它: 它的简谱是**排版渲染图**(不是扫描件), 笔画锐利、无水印, 虽只有 664-1125px
但 OCR 效果远好于 jianpucn 的同分辨率扫描图。实测对比见 train-work/jianpujia简谱样本.jpg。

站内结构:
  分类页  http://www.jianpujia.com/list/<cat>-<page>.html   例: 583 = 周杰伦
  曲谱页  http://www.jianpujia.com/jianpu/<id>.html          (吉他谱是 /jitapu/)
  图片    https://image.jianpujia.com/...                    (无扩展名, 需嗅探)

用法:
  py tools/crawl_jianpujia.py 583 周杰伦 200
  py tools/crawl_jianpujia.py 1252 邓丽君 200
"""
import os
import re
import sys
import time
import urllib.request

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CAT = sys.argv[1] if len(sys.argv) > 1 else "583"
NAME = sys.argv[2] if len(sys.argv) > 2 else "周杰伦"
TARGET = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 150
OUT = os.path.join("images-prep", f"jianpujia-{CAT}")
os.makedirs(OUT, exist_ok=True)


def fetch(url, binary=False, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "http://www.jianpujia.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


# 1) 翻分类页, 收集 /jianpu/ 详情页(跳过 /jitapu/ 吉他谱)
items = []
for page in range(0, 40):
    url = f"http://www.jianpujia.com/list/{CAT}-{page}.html"
    try:
        h = fetch(url)
    except Exception:
        break
    found = re.findall(r'href="(/jianpu/(\d+)\.html)"[^>]*>([^<]{2,90})', h)
    if not found:
        break
    new = [(i, t) for i, _id, t in found if i not in {x[0] for x in items}]
    if not new:
        break
    items.extend(new)
    print(f"  分类第 {page} 页: +{len(new)} (累计 {len(items)})", flush=True)
    if len(items) >= TARGET:
        break
    time.sleep(0.3)

items = items[:TARGET]
print(f"\n{NAME}: 收集到 {len(items)} 个简谱页, 开始下载")

ok = 0
for i, (path, title) in enumerate(items, 1):
    sid = re.search(r"/(\d+)\.html", path).group(1)
    d = os.path.join(OUT, f"{safe(title)}__jianpujia-{sid}")
    if os.path.isdir(d) and os.listdir(d):
        ok += 1
        continue
    try:
        ph = fetch("http://www.jianpujia.com" + path)
    except Exception:
        continue
    imgs = re.findall(r'<img[^>]+src="((?:https?:)?//image\.jianpujia\.com/[^"]+)"', ph, re.I)
    if not imgs:
        continue
    os.makedirs(d, exist_ok=True)
    n = 0
    for k, iu in enumerate(dict.fromkeys(imgs)):
        full = iu if iu.startswith("http") else "http:" + iu
        try:
            data = fetch(full, binary=True, timeout=30)
        except Exception:
            continue
        if len(data) < 3000:      # 太小的多半是图标
            continue
        # 嗅探格式
        ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
        with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
            g.write(data)
        n += 1
        time.sleep(0.15)
    if n:
        ok += 1
        if ok % 20 == 0:
            print(f"  [{ok}/{len(items)}] {title[:40]}", flush=True)
    time.sleep(0.25)

print(f"\n完成: {ok} 首 -> {OUT}")
