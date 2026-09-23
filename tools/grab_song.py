# -*- coding: utf-8 -*-
"""在 jianpu.cn 搜关键词并把曲谱图抓下来(纯网络, 不用 GPU)。
用法: py -3.13 tools/grab_song.py 傻女 [目标数] [目录slug]
"""
import os, re, sys, time, urllib.parse, urllib.request

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
KEY = sys.argv[1] if len(sys.argv) > 1 else "傻女"
TARGET = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 6
SLUG = sys.argv[3] if len(sys.argv) > 3 else re.sub(r"[^0-9A-Za-z]", "", KEY)[:20] or "kw"
OUT = os.path.join("images-prep", f"jianpucn-{SLUG}")
os.makedirs(OUT, exist_ok=True)


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": "http://www.jianpu.cn/"})
    with urllib.request.urlopen(req, timeout=30) as r:
        b = r.read()
    return b if binary else b.decode("utf-8", errors="replace")


def safe(s):
    s = re.sub(r"&nbsp;|\s+", " ", s).strip()
    s = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", s)
    return re.sub(r"_{2,}", "_", s)[:60] or "untitled"


q = urllib.parse.quote(KEY)
html = fetch(f"http://www.jianpu.cn/search/?q={q}")
open("train-work/_search_dump.html", "w", encoding="utf-8").write(html)
print(f"搜索页长度 {len(html)}，已存 train-work/_search_dump.html")

# 曲谱页链接
links = []
for m in re.finditer(r'href="(/[a-z]+/\d+\.html)"[^>]*>(.*?)</a>', html, re.S | re.I):
    href, txt = m.group(1), re.sub(r"<[^>]+>", "", m.group(2))
    txt = re.sub(r"\s+", " ", txt).strip()
    if txt and (href, txt) not in links:
        links.append((href, txt))
print(f"候选曲谱页 {len(links)} 个:")
for h, t in links[:20]:
    print(f"   {h}   {t}")

n = 0
for href, title in links:
    if n >= TARGET:
        break
    if KEY not in title and KEY.replace(" ", "") not in title.replace(" ", ""):
        continue
    try:
        page = fetch("http://www.jianpu.cn" + href)
    except Exception as e:
        print(f"   跳过 {href}: {e}")
        continue
    imgs = []
    for m in re.finditer(r'(https?://[^"\'\s<>]+?\.(?:jpg|jpeg|png|gif))', page, re.I):
        u = m.group(1)
        if u not in imgs:
            imgs.append(u)
    if not imgs:
        print(f"   {title}: 页面里没有图片")
        continue
    d = os.path.join(OUT, f"{safe(title)}__jianpucn-{re.sub(r'[^0-9]', '', href)}")
    os.makedirs(d, exist_ok=True)
    k = 0
    for u in imgs[:3]:
        k += 1
        ext = os.path.splitext(urllib.parse.urlparse(u).path)[1] or ".jpg"
        dst = os.path.join(d, f"{k:03d}{ext}")
        try:
            open(dst, "wb").write(fetch(u, binary=True))
            print(f"   {title}  [{k}] {os.path.getsize(dst)//1024} KB -> {dst}")
        except Exception as e:
            print(f"   {title}  [{k}] 下载失败: {e}")
    n += 1
    time.sleep(0.6)

print(f"\n完成: {n} 首 -> {OUT}")
