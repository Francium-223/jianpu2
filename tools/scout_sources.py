# -*- coding: utf-8 -*-
"""源侦察: 诊断 jianpujia 的检索 + 摸清 qupu123 的曲谱页面结构。

B(jianpujia): 检索返回空白页, 试 Referer / 正确参数 / 列表页入口
A(qupu123):  检索结果里混着吉他谱, 需要摸清路径前缀哪些是"简谱"类
"""
import re
import sys
import urllib.parse
import urllib.request
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(url, referer=None, data=None, enc="utf-8"):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
    if referer:
        req.add_header("Referer", referer)
    with urllib.request.urlopen(req, timeout=25) as r:
        raw = r.read()
    for e in (enc, "gbk", "utf-8"):
        try:
            return raw.decode(e)
        except Exception:
            pass
    return raw.decode("utf-8", errors="replace")


print("=" * 60)
print("B) jianpujia 检索诊断")
print("=" * 60)
kw = urllib.parse.quote("夜曲")
tries = [
    ("GET 无 referer", f"http://www.jianpujia.com/e/search/index.php?keyboard={kw}&show=title&tempid=1&tbname=news", None),
    ("GET 带 referer", f"http://www.jianpujia.com/e/search/index.php?keyboard={kw}&show=title&tempid=1&tbname=news",
     "http://www.jianpujia.com/"),
    ("POST 带 referer", "http://www.jianpujia.com/e/search/index.php", "http://www.jianpujia.com/"),
]
for label, url, ref in tries:
    try:
        if label.startswith("POST"):
            data = urllib.parse.urlencode({"keyboard": "夜曲", "show": "title", "tempid": "1",
                                           "tbname": "news", "mid": "1", "dopost": "search"}).encode()
            h = get(url, referer=ref, data=data, enc="gbk")
        else:
            h = get(url, referer=ref, enc="gbk")
        links = re.findall(r'href="(/[a-z]+/\d+\.html)"', h)
        print(f"  {label:16s} 长度 {len(h):6d}  曲谱链接 {len(links)}")
        if len(h) < 2500:
            txt = re.sub(r"<[^>]+>", " ", h)
            txt = re.sub(r"\s+", " ", txt).strip()
            print(f"       内容: {txt[:200]}")
    except Exception as e:
        print(f"  {label:16s} 失败 {type(e).__name__}")

# 列表页入口: 首页给出的 /list/NNNN-0.html
try:
    home = get("http://www.jianpujia.com/", enc="gbk")
    cats = re.findall(r'href="(/list/\d+-0\.html)"[^>]*>([^<]{2,30})', home)
    print(f"\n  首页分类入口 {len(cats)} 个:")
    for u, t in cats[:10]:
        print(f"     {u}  {t.strip()}")
except Exception as e:
    print("  首页失败", e)

print()
print("=" * 60)
print("A) qupu123 路径前缀分布 (搜 周杰伦)")
print("=" * 60)
try:
    h = get("https://www.qupu123.com/Search?keys=" + urllib.parse.quote("周杰伦"), enc="utf-8")
    links = re.findall(r'href="(/[^"]+?\.html)"[^>]*>([^<]{0,70})</a>', h)
    pref = Counter()
    jianpu = []
    for u, t in links:
        pref[u.split("/")[1] if "/" in u[1:] else "?"] += 1
        if "简谱" in t or "jianpu" in u:
            jianpu.append((u, t.strip()))
    print(f"  总链接 {len(links)}; 路径前缀分布:")
    for k, v in pref.most_common(12):
        print(f"     /{k}/  {v} 条")
    print(f"\n  标题带'简谱'的 {len(jianpu)} 条:")
    for u, t in jianpu[:6]:
        print(f"     {u}  {t}")
except Exception as e:
    print("  失败", e)
