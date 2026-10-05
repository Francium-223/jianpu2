# -*- coding: utf-8 -*-
"""把两站"自报总量"找出来 —— 决定算账分母。只读。"""
import re
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "https://www.qupu123.com/"})
    with tlsfetch.urlopen(req, timeout=30) as r:
        return r.read()


def gbk(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("gbk", errors="replace")


print("=== qupu123 首页导航(找分类与自报数) ===")
h = get("https://www.qupu123.com/").decode("utf-8", "replace")
links = re.findall(r'href="(/([a-z0-9_]+)/)"[^>]*>([^<]{1,20})</a>', h)
seen = {}
for href, slug, name in links:
    if slug in ("admin", "zona", "ldy"):
        continue
    seen.setdefault(slug, name)
print("  首页一级栏目: %s" % ", ".join("%s(%s)" % (v, k) for k, v in sorted(seen.items())))
for m in re.findall(r"共\s*[\d,]+\s*[条张首份]", h)[:10]:
    print("  首页自报数: %s" % m)

print("\n=== qupu123 各栏目页自报数 ===")
for slug in sorted(seen):
    u = "https://www.qupu123.com/%s/" % slug
    try:
        t = get(u).decode("utf-8", "replace")
    except Exception as e:
        print("  %-16s 失败 %s" % (slug, e))
        continue
    nums = re.findall(r"共\s*([\d,]+)\s*([条张首份])", t)
    pages = re.findall(r"(\d+)\s*页", t)
    idx = len(re.findall(r'href="/%s/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html"' % slug, t))
    print("  %-16s %-10s 自报 %s %s · 页数 %s · 首页条目 %d" % (
        slug, seen[slug], nums[:3], "", pages[:3], idx))
    time.sleep(1.2)

print("\n=== jianpu.cn 首页导航 + 分类自报数(看原始片段) ===")
h2 = gbk("http://www.jianpu.cn/")
nav = re.findall(r"href='(/[a-z0-9_]+)'[^>]*>([^<]{1,14})</a>", h2)
print("  首页栏目: %s" % ", ".join("%s(%s)" % (n, s) for s, n in dict(nav).items()))
# 找"共"字附近原文
for m in re.finditer(r".{0,40}共.{0,40}", h2):
    print("  片段: %r" % m.group(0))
    break
for cat in ("erzigepu", "hechangpu"):
    t = gbk("http://www.jianpu.cn/%s" % cat)
    hits = re.findall(r".{0,30}共\s*[\d,]+.{0,30}", t)
    print("  [%s] 含'共'片段: %s" % (cat, hits[:3]))
    hits2 = re.findall(r"(\d[\d,]{2,})\s*(?:首|条|张|个)", t)
    print("  [%s] 数字+量词: %s" % (cat, sorted(set(hits2), key=lambda x: -len(x))[:8]))
    # 末页
    lp = re.findall(r"href='/%s/(\d+)\.htm'" % cat, t)
    print("  [%s] 首页出现的页号链接: %s" % (cat, sorted(set(int(x) for x in lp))[-6:] or "无"))
    time.sleep(1.2)
