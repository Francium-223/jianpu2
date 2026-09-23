# -*- coding: utf-8 -*-
"""逐首去源站核实: 这些"缺失"的歌, 源站到底有没有谱页?

对每首歌试三种站内搜索(只读状态与标题, 不下载):
  qupu123  : /Search?keys=<歌名>
  jianpu.cn: /search/?q=<歌名>
  jianpujia: /e/search/?keyboard=<歌名>
只报"命中链接数 / 同名标题数", 不做推断。并发 6 线程。
"""
import concurrent.futures as cf
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

TITLES = sys.argv[1:]
if not TITLES:
    sys.exit("用法: py probe_source_hits.py 歌名1 歌名2 ...")


def get(u, to=12, referer="https://www.qupu123.com/"):
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": referer})
    with urllib.request.urlopen(req, timeout=to, context=CTX) as r:
        return r.read()


def probe_q123(t):
    u = "https://www.qupu123.com/Search?keys=" + urllib.parse.quote(t)
    try:
        h = get(u).decode("utf-8", "replace")
    except Exception as e:
        return f"ERR {type(e).__name__}"
    links = re.findall(r'href="(/[a-z]+/(?:[a-z]+/)?p?\d+\.html)"', h)
    titles = re.findall(r'href="/[a-z]+/(?:[a-z]+/)?p?\d+\.html"[^>]*>([^<]{1,60})<', h)
    exact = [x.strip() for x in titles if t in x]
    return f"链接{len(links):>3} 同名{len(exact):>2}" + (f"  例:{exact[0][:26]}" if exact else "")


def probe_jpcn(t):
    u = "http://www.jianpu.cn/search/?q=" + urllib.parse.quote(t)
    try:
        h = get(u, referer="http://www.jianpu.cn/").decode("gbk", "replace")
    except Exception as e:
        return f"ERR {type(e).__name__}"
    hits = re.findall(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{1,60})<", h)
    exact = [x.strip() for _p, x in hits if t in x]
    return f"链接{len(hits):>3} 同名{len(exact):>2}" + (f"  例:{exact[0][:26]}" if exact else "")


def probe_jpj(t):
    u = "https://www.jianpujia.com/e/search/?keyboard=" + urllib.parse.quote(t)
    try:
        h = get(u, referer="https://www.jianpujia.com/").decode("utf-8", "replace")
    except Exception as e:
        return f"ERR {type(e).__name__}"
    hits = re.findall(r'href="(https?://[^"]*?/jianpu/\d+\.html)"[^>]*>([^<]{1,60})<', h)
    exact = [x.strip() for _p, x in hits if t in x]
    return f"链接{len(hits):>3} 同名{len(exact):>2}" + (f"  例:{exact[0][:26]}" if exact else "")


def work(t):
    lines = [f"--- {t} ---"]
    for name, fn in (("qupu123", probe_q123), ("jianpucn", probe_jpcn), ("jianpujia", probe_jpj)):
        lines.append(f"    {name:<9} {fn(t)}")
        time.sleep(0.25)
    return "\n".join(lines)


with cf.ThreadPoolExecutor(max_workers=6) as pool:
    for res in pool.map(work, TITLES):
        print(res, flush=True)
