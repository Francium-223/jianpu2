#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 source 里的「站点-ID」变成**该曲在原谱站的确切页面 URL**, 而且每一条都实际抓一次核对。

为什么需要它: `data.jsonl` 里只有 `source=qupu123-300587` 这种 ID, 前端从前只能链到**站点首页**。
用户口径(2026-09-23): 「我要的是跳转到它具体收录的那一页」—— 原谱站这一页是**能推出来的**,
外部站(网易云/QQ音乐/B站/YouTube)推不出来, 只能人工补 `link=`(另有一套工具)。

三个站点的规则(都实测过):
  * jianpucn   http://www.jianpu.cn/pu/<id前两位>/<id>.htm        规则确定, 不存在的 id 会硬 404
  * jianpujia  https://www.jianpujia.com/<section>/<id>.html      逐 section 试(section 由 id 推不出)
  * qupu123    https://www.qupu123.com/Search?keys=<曲名>          先用站点搜索**找到**页面,
               再从结果里取 `/…/p<id>.html` 那一条 —— 搜索只是找页面手段, 存下来的必须是确切页

核对(每条都要过):
  抓到 200 且 (页面 <title> 归一化后含曲名 -> 记 `title`, 最强) 否则 (URL 里的 id 与 source 完全一致 -> 记 `id`)。

输出 `jianpu-db/source_pages.json`:  {"<site>-<id>": {"url":..., "t": 页面标题, "via": "title|id", "at": "日期"}}
可断点续跑: 已在输出里的键默认跳过; 每 25 条落一次盘。

用法:
  python3 jianpu2/tools/verify_source_urls.py --limit 30          # 小样试跑
  python3 jianpu2/tools/verify_source_urls.py --sites jianpucn    # 只跑某站
  python3 jianpu2/tools/verify_source_urls.py                     # 全量(约 1.1 万次请求, 建议后台跑)
"""
import argparse
import collections
import concurrent.futures as cf
import json
import os
import re
import ssl
import sys
import threading
import time
import urllib.parse
import urllib.request

import tlsfetch                                     # 同目录: 取页 + 证书过期兜底

UA = "Mozilla/5.0 (X11; Linux x86_64) jianpu-corpus-link-curator/1.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                                   # jianpu2/
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
CACHE = os.path.join(ROOT, "train-work", "source_urls_cache")
OUT_DEFAULT = os.path.join(DB, "source_pages.json")

sys.stdout.reconfigure(encoding="utf-8")

# jianpujia 的栏目(取自 crawler.py 的列表页正则); 按"最常见"排前面, 命中即停
JIANPUJIA_SECTIONS = ["jianpu", "gangqinpu", "jitapu", "youkelilipu", "erhu", "guzheng",
                      "pipa", "zongpu", "jiaoxue", "qita", "dizu", "hulusi", "sax",
                      "dianziqin", "shoufengqin", "xiaotiqin", "zhongruan", "yangqin"]

_host_lock = {}
_host_last = {}
_lock = threading.Lock()


def _ssl_ctx():
    """(留着给外部调用) —— 但**别再拿它当"证书过期兜底"**: create_default_context() 本身不会抛,
    证书过期是在握手里才炸的, 所以原来那句 except 永远走不到(2026-09-25 实测: qupu123 证书
    09-23 过期, 这里照样返回严格 context -> 请求全被记成 status 0, 白白停摆两天)。
    真正的兜底在 fetch() 里, 走 tlsfetch.urlopen。"""
    try:
        return ssl.create_default_context()
    except Exception:
        return ssl._create_unverified_context()


def polite(url, interval):
    """同一 host 的请求之间至少隔 interval 秒(别把人家站点打崩)。"""
    host = urllib.parse.urlsplit(url).netloc
    with _lock:
        lk = _host_lock.setdefault(host, threading.Lock())
    with lk:
        wait = interval - (time.time() - _host_last.get(host, 0))
        if wait > 0:
            time.sleep(wait)
        _host_last[host] = time.time()


def fetch(url, interval=0.25, timeout=20, referer=None):
    polite(url, interval)
    hdr = {"User-Agent": UA, "Accept-Language": "zh-CN,zh;q=0.9"}
    if referer:
        hdr["Referer"] = referer
    req = urllib.request.Request(url, headers=hdr)
    try:
        # tlsfetch: 先正常校验证书, 只有真的"证书过期/校验失败"才对**这个 host** 放开一次重试。
        # (2026-09-25: qupu123 的证书 09-23 到期, 之前这里一律记成 status 0 = "打不开"。)
        with tlsfetch.urlopen(req, timeout=timeout) as r:
            return r.status, r.read(500000)
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:
        return 0, str(e).encode()


def decode(raw, site):
    for enc in (("gb18030", "utf-8") if site == "jianpucn" else ("utf-8", "gb18030")):
        try:
            return raw.decode(enc, "ignore")
        except Exception:
            continue
    return raw.decode("utf-8", "ignore")


TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)
_PUNCT = re.compile(r"[\s\-_·、,，。.（）()【】\[\]《》!！?？:：;；'\"“”‘’~～|/\\+&]")


def norm(s):
    return _PUNCT.sub("", (s or "")).casefold()


def page_title(html):
    m = TITLE_RE.search(html or "")
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def check(url, want_title, want_id, site, interval, id_is_evidence=True):
    """`id_is_evidence`: URL 里的 id 算不算**独立证据** —— 取决于 URL 是怎么来的。

    2026-09-25 审计发现: `candidates()` 对 jianpucn/jianpujia 是**按 id 拼**出 URL 的
    (`/pu/{sid[:2]}/{sid}.htm`), 所以"路径里有 id"是**循环论证** —— 只证明了"自己拼的 URL
    返回 200"。只有 qupu123 的 URL 是 `find_qupu123()` **站内搜索**搜出来的, id 才算真证据。
    以前不区分, 于是 jianpucn 64 + jianpujia 36 = 100 条被记成 `via:id`, 其实没有独立证据。
    """
    code, raw = fetch(url, interval=interval)
    if code != 200 or not raw:
        return None
    html = decode(raw, site)
    t = page_title(html)
    nt, nw = norm(t), norm(want_title)
    if nw and len(nw) >= 2 and nw in nt:
        return ("title", t)
    if id_is_evidence and want_id and re.search(r"/p?%s\.(html|htm)$" % re.escape(want_id),
                                                urllib.parse.urlsplit(url).path):
        # 次强证据: URL 里的 id 与 source 完全一致 —— **仅当 URL 是搜出来的**(qupu123)
        return ("id", t)
    return None


def qp_prefixes(cache_dir, interval):
    """qupu123: 从 sitemap 里取候选栏目前缀(按出现频次排序), 只抓一次并缓存。"""
    path = os.path.join(cache_dir, "qupu123_prefixes.json")
    if os.path.exists(path):
        return json.load(open(path, encoding="utf-8"))
    code, raw = fetch("https://www.qupu123.com/sitemap.xml", interval=interval, timeout=60)
    pref = collections.Counter()
    if code == 200:
        for m in re.finditer(r"<loc>([^<]+)</loc>", decode(raw, "qupu123")):
            p = urllib.parse.urlsplit(m.group(1).strip()).path
            mm = re.match(r"^/(.+?)/p\d+\.html$", p)
            if mm:
                pref[mm.group(1)] += 1
    os.makedirs(cache_dir, exist_ok=True)
    json.dump([p for p, _ in pref.most_common()], open(path, "w", encoding="utf-8"), ensure_ascii=False)
    return [p for p, _ in pref.most_common()]


def find_qupu123(key, title, interval, prefixes):
    """先用站点搜索定位到 p<id>.html, 找不到再按栏目前缀试。"""
    sid = key.split("-", 1)[1]
    code, raw = fetch("https://www.qupu123.com/Search?keys=" + urllib.parse.quote(title),
                      interval=interval, referer="https://www.qupu123.com/")
    if code == 200:
        for m in re.finditer(r'href="(/[^"]*?/p%s\.html)"' % re.escape(sid), decode(raw, "qupu123")):
            return "https://www.qupu123.com" + m.group(1)
    for p in prefixes[:6]:                       # 搜索没给到, 就试最常见的几个栏目
        u = "https://www.qupu123.com/%s/p%s.html" % (p, sid)
        c, _ = fetch(u, interval=interval, referer="https://www.qupu123.com/")
        if c == 200:
            return u
    return None


def candidates(key, title, interval, prefixes):
    site, _, sid = key.partition("-")
    if site == "jianpucn" and sid.isdigit():
        return ["http://www.jianpu.cn/pu/%s/%s.htm" % (sid[:2], sid)]
    if site == "jianpujia" and sid.isdigit():
        return ["https://www.jianpujia.com/%s/%s.html" % (s, sid) for s in JIANPUJIA_SECTIONS]
    if site == "qupu123" and sid.isdigit():
        u = find_qupu123(key, title, interval, prefixes)
        return [u] if u else []
    return []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--sites", default="jianpucn,jianpujia,qupu123", help="只跑这些站(逗号分隔)")
    ap.add_argument("--limit", type=int, default=0, help="只处理前 N 首(试跑用)")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--interval", type=float, default=0.25, help="同 host 两次请求的最小间隔(秒)")
    ap.add_argument("--recheck", action="store_true", help="已核对过的也重来")
    a = ap.parse_args()

    sites = set(x.strip() for x in a.sites.split(",") if x.strip())
    rows = [json.loads(l) for l in open(a.data, encoding="utf-8") if l.strip()]
    todo, seen = [], set()
    for r in rows:
        s = r.get("source") or []
        s = s[0] if isinstance(s, list) and s else (s if isinstance(s, str) else "")
        if not s or s in seen or s.split("-")[0] not in sites:
            continue
        seen.add(s)
        todo.append((s, r.get("title") or ""))
    if a.limit:
        todo = todo[:a.limit]

    old = {}
    if os.path.exists(a.out) and not a.recheck:
        old = json.load(open(a.out, encoding="utf-8"))
    todo = [(k, t) for k, t in todo if k not in old]
    print("待办 %d 个 source(已有 %d 个); 站点 %s; workers=%d interval=%s"
          % (len(todo), len(old), sorted(sites), a.workers, a.interval), flush=True)

    os.makedirs(CACHE, exist_ok=True)
    prefixes = qp_prefixes(CACHE, a.interval) if "qupu123" in sites else []
    if prefixes:
        print("qupu123 候补栏目(按频次):", prefixes[:8], flush=True)

    out = dict(old)
    lock = threading.Lock()
    stat = collections.Counter()
    t0 = time.time()

    def work(item):
        key, title = item
        try:
            for u in candidates(key, title, a.interval, prefixes):
                got = check(u, title, key.split("-", 1)[-1], key.split("-")[0], a.interval,
                            id_is_evidence=(key.split("-")[0] == "qupu123"))
                if got:
                    via, t = got
                    with lock:
                        out[key] = {"url": u, "t": t, "via": via,
                                    "at": time.strftime("%Y-%m-%d")}
                        stat[key.split("-")[0] + ":" + via] += 1
                        n = sum(stat.values())
                        if n % 25 == 0:
                            json.dump(out, open(a.out, "w", encoding="utf-8"),
                                      ensure_ascii=False, indent=1)
                            print("  ...已核对 %d 条 (%.1f 分钟)" % (n, (time.time() - t0) / 60), flush=True)
                    return True
            with lock:
                stat[key.split("-")[0] + ":miss"] += 1
            return False
        except Exception as e:
            with lock:
                stat[key.split("-")[0] + ":err"] += 1
            return False

    with cf.ThreadPoolExecutor(max_workers=a.workers) as ex:
        list(ex.map(work, todo))

    json.dump(out, open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("\n写出 %s (%d 条, %.1f 分钟)" % (a.out, len(out), (time.time() - t0) / 60))
    for k, v in sorted(stat.items()):
        print("   %-22s %d" % (k, v))
    print("覆盖: 待办 %d 条中核对成功 %d 条" % (len(todo), sum(v for k, v in stat.items() if not k.endswith(("miss", "err")))))


if __name__ == "__main__":
    main()
