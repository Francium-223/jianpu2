# -*- coding: utf-8 -*-
"""站点实测探针: robots.txt / 分类页规模 / 多图详情页图数。只读, 不改任何东西。"""
import re
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(url, binary=False, referer="https://www.qupu123.com/"):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": referer})
    with tlsfetch.urlopen(req, timeout=30) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


def gbk(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("gbk", errors="replace")


print("=========== 1) robots.txt ===========")
for name, u in (("qupu123", "https://www.qupu123.com/robots.txt"),
                ("jianpu.cn", "http://www.jianpu.cn/robots.txt")):
    try:
        t = get(u) if "qupu123" in name else gbk(u)
        print("[%s] %s -> %d 字节" % (name, u, len(t.encode("utf-8"))))
        print(t.strip()[:1500] or "(空)")
    except Exception as e:
        print("[%s] %s -> 失败 %s: %s" % (name, u, type(e).__name__, e))
    print("-" * 60)

print("\n=========== 2) qupu123 /tongsu/ 列表规模 ===========")
for p in (1, 2):
    u = "https://www.qupu123.com/tongsu/" + ("" if p == 1 else "%d.html" % p)
    try:
        h = get(u)
    except Exception as e:
        print("  第%d页失败 %s" % (p, e))
        continue
    items = re.findall(r'href="(/tongsu/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html)"[^>]*>([^<]{2,90})<', h)
    # 抓"共 N 条 / N 页"这类自报数
    nums = re.findall(r"(共\s*\d+\s*[条页张]|\d+\s*页|共\s*\d+)", h)
    print("  第%d页: 条目 %d · 自报数样本 %s" % (p, len(items), nums[:8]))
    # 找末页链接
    last = re.findall(r'href="/tongsu/(?:list_)?(\d+)\.html"', h)
    if last:
        print("    页号链接最大: %s" % max(int(x) for x in last))
    time.sleep(1.0)

print("\n=========== 3) jianpu.cn 12 个简谱分类的规模 ===========")
CATS = ["yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu"]
tot = 0
for cat in CATS:
    u = "http://www.jianpu.cn/%s" % cat
    try:
        h = gbk(u)
    except Exception as e:
        print("  %-16s 失败 %s" % (cat, e))
        continue
    m = re.search(r"共\s*(\d+)\s*[条首张]", h)
    n = int(m.group(1)) if m else None
    links = re.findall(r"href='(/%s/\d+\.htm)'" % cat, h)
    last = max((int(re.search(r"/(\d+)\.htm", x).group(1)) for x in links), default=None)
    per = len(re.findall(r"href='(/pu/\d+/\d+\.htm)'", h))
    if n:
        tot += n
    print("  %-16s 自报 %s · 首页条目 %d · 首页可见末页号 %s" % (cat, n, per, last))
    time.sleep(1.0)
print("  12 类自报合计: %s" % tot)

print("\n=========== 4) 多图详情页实测 ===========")
IMG_RE = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)
for sid in ("194129", "438812", "90797"):
    u = "http://www.jianpu.cn/pu/%s/%s.htm" % (sid[:2], sid)
    try:
        h = gbk(u)
    except Exception as e:
        print("  %s -> 失败 %s" % (u, e))
        continue
    imgs = [x for x in dict.fromkeys(IMG_RE.findall(h)) if "logo" not in x.lower()]
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", h, re.S)
    print("  %s · 曲名=%r · 谱图 %d 张: %s" % (
        u, re.sub(r"<[^>]+>", "", m1.group(1)).strip() if m1 else "?", len(imgs), imgs))
    time.sleep(1.0)

print("\n=========== 5) qupu123 详情页图数抽样 ===========")
for path in ("/tongsu/p/194129.html",):
    pass
for u in ("https://www.qupu123.com/tongsu/p89123.html",):
    try:
        h = get(u)
    except Exception as e:
        print("  %s 失败 %s" % (u, e))
        continue
    imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', h, re.I)
    imgs = [urllib.parse.urljoin("https://www.qupu123.com/", x) for x in dict.fromkeys(imgs)]
    imgs = [x for x in imgs if "/Public/Uploads/" in x or "/data2/uploads/" in x]
    print("  %s -> 谱图 %d 张" % (u, len(imgs)))
