# -*- coding: utf-8 -*-
"""qupu123 声乐 6 个栏目自报条目数 + jianpu.cn 总量线索。只读。"""
import re
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def g(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA,
                                             "Referer": "https://www.qupu123.com/"})
    with tlsfetch.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


def gbk(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("gbk", errors="replace")


SEC = [("minge", "民歌"), ("tongsu", "通俗"), ("meisheng", "美声"),
       ("hechang", "合唱"), ("shaoer", "少儿"), ("waiguo", "外国")]
print("=== qupu123 声乐 6 栏目 ===")
tot = 0
for slug, name in SEC:
    try:
        t = g("https://www.qupu123.com/%s/" % slug)
    except Exception as e:
        print("  %-10s 失败 %s" % (slug, type(e).__name__))
        continue
    m = re.search(r"共\s*([\d,]+)\s*([条张首份])", t)
    pg = re.search(r"([\d,]+)\s*页", t)
    n = int(m.group(1).replace(",", "")) if m else 0
    tot += n
    print("  /%-9s %-4s 自报 %7d %s · %s 页 · 首页条目 %d" % (
        slug + "/", name, n, m.group(2) if m else "?", pg.group(1) if pg else "?",
        len(re.findall(r'href="/%s/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html"' % slug, t))))
    time.sleep(1.1)
print("  声乐 6 栏目合计自报: %d" % tot)

print("\n=== qupu123 其他大栏目(供参照) ===")
for slug in ("qiyue", "xiqu", "pdf", "yuanchuang", "jipu", "puyou/shangchuan"):
    try:
        t = g("https://www.qupu123.com/%s/" % slug)
    except Exception as e:
        print("  /%-18s 失败 %s" % (slug, type(e).__name__))
        continue
    m = re.search(r"共\s*([\d,]+)\s*([条张首份])", t)
    print("  /%-18s 自报 %s" % (slug + "/", m.group(0) if m else "无"))
    time.sleep(1.1)

print("\n=== jianpu.cn 总量线索 ===")
h = gbk("http://www.jianpu.cn/")
for pat in (r"共\s*[\d,]+\s*[首条张个]", r"[\d,]{4,}\s*[首条张个]",
            r"收录[^<]{0,40}", r"总数[^<]{0,40}", r"<title>(.*?)</title>"):
    hits = re.findall(pat, h)
    print("  %-28s -> %s" % (pat, hits[:6]))
