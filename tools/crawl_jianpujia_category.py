# -*- coding: utf-8 -*-
"""按 jianpujia 的**分类页**整片抓谱(不是逐个歌名打补丁)。

分类 id(来自首页, 2026-09-23 实测):
  主题曲 388   儿歌 3462   影视 21436   民歌 22807   草原 6223
  游戏 20961   伴奏 21190   世界名曲 21159   钢琴谱/吉他谱/尤克里里谱/弹奏教学
结构: /list/<id>-<页>.html; 真列表在 `<div class="mainl">…<!--@ mainl-->` 之间(右侧 mainr 是每页
重复的推荐侧栏, 不切掉会污染且会提前退出翻页)。站点 SSL 证书已过期, 必须跳过校验。

用法: py -3.13 tools/crawl_jianpujia_category.py <分类id> <分类名> [最多下几张=400] [从第几页开始=0]
"""
import os
import re
import ssl
import sys
import time
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()
BASE = "http://www.jianpujia.com"

CAT = sys.argv[1]
NAME = sys.argv[2] if len(sys.argv) > 2 else CAT
CAP = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 400
START = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 0
OUT = os.path.join("images-prep", f"jianpujia-cat{CAT}")
os.makedirs(OUT, exist_ok=True)


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=35, context=CTX) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


def mainl(h):
    i = h.find('class="mainl"')
    if i < 0:
        return ""
    j = h.find("<!--@ mainl-->", i)
    return h[i:j if j > i else len(h)]


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


items, last = [], None
page = START
while len(items) < CAP * 2:
    try:
        h = fetch(f"{BASE}/list/{CAT}-{page}.html")
    except Exception:
        break
    if last is None:
        nums = [int(x) for x in re.findall(r"/list/%s-(\d+)\.html" % CAT, h)]
        last = max(nums) if nums else 0
        print(f"   {NAME}(id={CAT}): 共 {last+1} 页", flush=True)
    found = re.findall(r'href="(/jianpu/(\d+)\.html)"[^>]*>([^<]{2,90})', mainl(h))
    items += [(p, t) for p, _i, t in found if p not in {x[0] for x in items}]
    if page >= last:
        break
    page += 1
    if page % 20 == 0:
        print(f"   已翻 {page} 页, 收集 {len(items)}", flush=True)
    time.sleep(0.25)

print(f"{NAME}: 收集 {len(items)} 个谱页, 下载上限 {CAP}", flush=True)
ok = 0
for path, title in items:
    if ok >= CAP:
        break
    sid = re.search(r"/(\d+)\.html", path).group(1)
    d = os.path.join(OUT, f"{safe(title)}__jianpujia-{sid}")
    if os.path.isdir(d) and os.listdir(d):
        ok += 1
        continue
    try:
        ph = fetch(BASE + path)
    except Exception:
        continue
    imgs = re.findall(r'<img[^>]+src="((?:https?:)?//image\.jianpujia\.com/[^"]+)"', ph, re.I)
    if not imgs:
        continue
    os.makedirs(d, exist_ok=True)
    n = 0
    for iu in dict.fromkeys(imgs):
        full = iu if iu.startswith("http") else "http:" + iu
        try:
            data = fetch(full, binary=True)
        except Exception:
            continue
        if len(data) < 3000:
            continue
        ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
        with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
            g.write(data)
        n += 1
        time.sleep(0.12)
    if n:
        ok += 1
        if ok % 25 == 0:
            print(f"   [{ok}/{CAP}] {title[:44]}", flush=True)
    time.sleep(0.2)

print(f"\n完成: {ok} 张 -> {OUT}")
