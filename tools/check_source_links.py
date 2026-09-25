#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""复查 `source_pages.json` 里**已记录**的原谱页链接是否还活着（只读，不改任何数据）。

为什么要单独写一个: `verify_source_urls.py` 是"**重新定位**"（会给 qupu123 每条先搜一次、
再试栏目前缀），那是重建用的；这里只想知道"当初记下的那个 URL 现在还行不行"，
所以每条只打 **1 次**。附带记录:
  * http 状态 / 重定向后的地址
  * 页面标题（与当初记下的标题、以及语料曲名对比）
  * 失败时再试一把 `http://`（qupu123 的 http 端点是坏的: 同路径 http 404 / https 200）

用法:
    python3 tools/check_source_links.py --out /tmp/links.tsv
    python3 tools/check_source_links.py --out /tmp/x.tsv --limit 50 --workers 6
"""
import argparse
import collections
import concurrent.futures as cf
import io
import json
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
sys.path.insert(0, HERE)
import tlsfetch                                              # noqa: E402

DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
UA = "Mozilla/5.0 (X11; Linux x86_64) jianpu-corpus-link-check/1.0"
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)
PUNCT = re.compile(r"[\s\-_·、,，。.（）()【】\[\]《》!！?？:：;；'\"“”‘’~～|/\\+&]")
_lock = threading.Lock()
_host_last = {}
_host_lock = {}


def norm(s):
    return PUNCT.sub("", (s or "")).casefold()


def decode(raw, site):
    for enc in (("gb18030", "utf-8") if site in ("jianpucn",) else ("utf-8", "gb18030")):
        try:
            return raw.decode(enc, "ignore")
        except Exception:
            continue
    return raw.decode("utf-8", "ignore")


def polite(url, interval):
    host = urllib.parse.urlsplit(url).netloc
    with _lock:
        lk = _host_lock.setdefault(host, threading.Lock())
    with lk:
        w = interval - (time.time() - _host_last.get(host, 0))
        if w > 0:
            time.sleep(w)
        _host_last[host] = time.time()


def fetch(url, interval, timeout=8):
    polite(url, interval)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "zh-CN,zh;q=0.9"})
    try:
        with tlsfetch.urlopen(req, timeout=timeout) as r:
            return r.status, r.geturl(), r.read(300000), ""
    except urllib.error.HTTPError as e:
        return e.code, url, b"", "HTTPError"
    except Exception as e:                                    # noqa: BLE001
        return 0, url, b"", type(e).__name__


def page_title(html):
    m = TITLE_RE.search(html or "")
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pages", default=os.path.join(DB, "source_pages.json"))
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--out", default="/tmp/source_links.tsv")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--interval", type=float, default=0.25)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--timeout", type=float, default=8.0, help="单条超时(秒)")
    ap.add_argument("--retry-http", action="store_true", default=False,
                    help="404/410 时再试一次 http://（qupu123 的 http 端点坏了）")
    a = ap.parse_args()

    sp = json.load(io.open(a.pages, encoding="utf-8"))
    title_of = {}
    for ln in io.open(a.data, encoding="utf-8"):
        if not ln.strip():
            continue
        r = json.loads(ln)
        s = r.get("source") or []
        s = s[0] if isinstance(s, list) and s else (s if isinstance(s, str) else "")
        if s:
            title_of.setdefault(s, r.get("title") or "")
    todo = [(k, v) for k, v in sp.items() if isinstance(v, dict) and v.get("url")]
    if a.limit:
        todo = todo[:a.limit]
    print("待复查 %d 条 (workers=%d interval=%s)" % (len(todo), a.workers, a.interval), flush=True)

    rows, stat = [], collections.Counter()
    t0 = time.time()
    g = io.open(a.out, "w", encoding="utf-8", newline="\n")
    g.write("source\tsite\t判定\thttp\t备注\t最终地址\t原URL\t页面标题\t语料曲名\n")
    g.flush()

    def work(item):
        key, rec = item
        url = rec["url"]
        site = key.split("-")[0]
        code, final, raw, err = fetch(url, a.interval, a.timeout)
        t = page_title(decode(raw, site)) if raw else ""
        want_key = norm(title_of.get(key, ""))
        want_rec = norm(rec.get("t", ""))
        nt = norm(t)
        if code == 200 and not raw:
            verdict = "空响应"
        elif code == 200:
            if want_key and len(want_key) >= 2 and want_key in nt:
                verdict = "ok(曲名命中)"
            elif want_rec and len(want_rec) >= 2 and want_rec in nt:
                verdict = "ok(原记录标题命中)"
            else:
                verdict = "标题对不上"
        elif code in (404, 410):
            verdict = "死链%d" % code
        elif code == 0:
            verdict = "打不开:%s" % err
        else:
            verdict = "HTTP%d" % code
        extra = ""
        if a.retry_http and verdict.startswith("死链"):
            if url.startswith("https://"):
                c2, _f2, raw2, _e2 = fetch("http://" + url[len("https://"):], a.interval)
                extra = "http->%s" % c2
        with _lock:
            stat[site + "|" + verdict.split("(")[0].split(":")[0]] += 1
            row = (key, site, verdict, str(code), extra, final[:120], url[:120], t[:100], title_of.get(key, ""))
            rows.append(row)
            g.write("\t".join(x.replace("\t", " ") for x in row) + "\n")
            g.flush()                       # 边跑边写: 卡住时也能看已完成多少
            if len(rows) % 200 == 0:
                print("  ...%d/%d (%.1f 分钟)" % (len(rows), len(todo), (time.time() - t0) / 60), flush=True)
        return True

    with cf.ThreadPoolExecutor(max_workers=a.workers) as ex:
        list(ex.map(work, todo))

    g.close()

    print("\n用时 %.1f 分钟 -> %s" % ((time.time() - t0) / 60, a.out))
    tot = collections.Counter()
    for k, v in stat.items():
        site, verdict = k.split("|", 1)
        tot[verdict] += v
    print("按判定:")
    for k, v in tot.most_common():
        print("   %-16s %d" % (k, v))
    print("按站点:")
    bysite = collections.Counter()
    for k, v in stat.items():
        bysite[k.split("|")[0]] += v
    for k, v in bysite.most_common():
        print("   %-12s %d" % (k, v))
    return 0


if __name__ == "__main__":
    if any(x in ("-h", "--help") for x in sys.argv[1:]):
        print(__doc__)
        raise SystemExit(0)
    sys.exit(main())
