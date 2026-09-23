# -*- coding: utf-8 -*-
"""离线抓"源站谱页"的元数据(只抓页面, 不下图), 给 OCR 那批谱补标签用。**并发版**。

单线程 1.3s/个 x 3940 个 = 85 分钟 —— 太慢。这里按**站点分队列 + 每站若干线程**跑:
  * jianpu.cn  1 次请求/个(id 直接拼 URL: /pu/<id前两位>/<id>.htm)
  * jianpujia  1 次请求/个(/jianpu/<id>.html)
  * qupu123    **先看 sitemap 索引**(28525 条), 没有就用**站内搜索按曲名找到自己那一页**
               (实测 6/6 命中自己 id), 再抓页面 -> 2 次请求/个

各站怎么抽字段(只认显式标注, 不猜):
  jianpu.cn : title `《 郴 州 行 》 （张 也演唱） 张也`  -> 括号内 + "演唱"
  jianpujia : title `Baby_Song钢琴简谱_陈奕迅演唱-免费下载` -> `_X演唱`
  qupu123   : title `…_通俗曲谱_中国曲谱网` -> 曲谱大类; 作词/作曲只记进 note(不当歌手)
  没有"演唱"字样的页 -> 歌手留空(宁可空着, 也不把词曲作者标成演唱者)

结果落 train-work/page_meta.tsv(可续跑): source<TAB>url<TAB>title<TAB>歌手<TAB>分类<TAB>备注

用法:
  py -3.13 tools/harvest_page_meta.py --workers 10
"""
import io
import os
import re
import ssl
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
CACHE = "train-work/page_meta.tsv"
PLAN = "train-work/ocr_tag_plan.tsv"
IDXFILE = "train-work/site_url_index.tsv"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
WORKERS = 10
if "--workers" in sys.argv:
    WORKERS = int(sys.argv[sys.argv.index("--workers") + 1])

INSTR = ["钢琴", "吉他", "古筝", "二胡", "琵琶", "葫芦丝", "萨克斯", "手风琴",
         "电子琴", "尤克里里", "口琴", "笛", "提琴", "陶笛", "双排键"]
ROOTCAT = {"tongsu": "通俗", "minzu": "民歌", "minge": "民歌", "shaoer": "少儿",
           "meisheng": "美声", "hechang": "合唱", "waiguo": "外国", "xiqu": "戏曲",
           "jipu": "记谱", "yuanchuang": "原创", "qiyue": "器乐", "puyou": "谱友上传"}

URLIDX = {}
if os.path.exists(IDXFILE):
    for ln in io.open(IDXFILE, encoding="utf-8"):
        c = ln.rstrip("\n").split("\t")
        if len(c) >= 2:
            URLIDX[c[0]] = c[1]

_lock = threading.Lock()
_last = {}          # host -> 上次请求时间(每站自己限速, 别把站打挂)


def fetch(url, timeout=15, referer="https://www.qupu123.com/"):
    host = urllib.parse.urlparse(url).netloc
    with _lock:
        gap = 0.25 - (time.time() - _last.get(host, 0))
    if gap > 0:
        time.sleep(gap)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": referer})
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
            return r.read()
    finally:
        with _lock:
            _last[host] = time.time()


def txt(b):
    for enc in ("utf-8", "gbk"):
        try:
            return b.decode(enc)
        except Exception:
            pass
    return b.decode("utf-8", "replace")


def title_of(h):
    m = re.search(r"<title>(.*?)</title>", h, re.S)
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def clean_performer(s):
    s = re.sub(r"[\s_]", "", s)
    s = re.sub(r"^[\(\（\[【]|[\)\）\]】]$", "", s)
    return s if 2 <= len(s) <= 14 else ""


def meta_of(site, h, url):
    t = title_of(h)
    artist = ""
    au = []
    if site == "jianpucn":
        t = re.sub(r"\s*歌谱简谱网\s*$", "", t).replace(" ", "")
        m = re.search(r"[（(]([^）)]{1,20}?)演唱", t)
        if m:
            artist = clean_performer(m.group(1))
    elif site == "jianpujia":
        t = re.sub(r"-免费下载-简谱之家\s*$", "", t)
        m = re.search(r"_([^_\s]{2,14})演唱", t)
        if m:
            artist = clean_performer(m.group(1))
    else:
        if "中国曲谱网" not in t:
            return None
        m = re.search(r"[（(]([^）)]{0,14}?)(?:演唱|演奏)[）)]", t)
        if m:
            artist = clean_performer(m.group(1))
    md = re.search(r'<meta name="description" content="([^"]*)"', h)
    if md:
        for k, v in re.findall(r"(作词|作曲)：([^;；]+)", md.group(1)):
            au.append(f"{k}:{v.strip()}")
    cat = ""
    if site == "qupu123":
        m = re.search(r"_([\u4e00-\u9fff]{2,4})曲谱_", t)
        if m:
            cat = m.group(1)
        if not cat:
            m = re.search(r"qupu123\.com/([a-z]+)/", url)
            if m:
                cat = ROOTCAT.get(m.group(1), "")
    for k in INSTR:
        if k in t:
            cat = cat or k
            break
    return {"title": t, "artist": artist, "cat": cat,
            "note": site + (" " + " ".join(au) if au else "")}


def find_q123(name, sid):
    want = sid.split("-", 1)[1]
    u = f"https://www.qupu123.com/Search?keys={urllib.parse.quote(name)}"
    try:
        h = txt(fetch(u, 15))
    except Exception:
        return ""
    for path, i in re.findall(r'href="(/[a-z]+/(?:[a-z]+/)?p?(\d+)\.html)"', h):
        if i == want:
            return "https://www.qupu123.com" + path
    return ""


def work(job):
    s, name = job
    site, i = s.split("-", 1)
    url = ""
    try:
        if site == "jianpucn":
            url = f"http://www.jianpu.cn/pu/{i[:2]}/{i}.htm"
            m = meta_of(site, txt(fetch(url, 15, "http://www.jianpu.cn/")), url)
        elif site == "jianpujia":
            url = f"https://www.jianpujia.com/jianpu/{i}.html"
            m = meta_of(site, txt(fetch(url, 15, "https://www.jianpujia.com/")), url)
        else:
            url = URLIDX.get(s, "") or find_q123(name, s)
            m = meta_of(site, txt(fetch(url, 15)), url) if url else None
            if m is None:
                m = {"title": "", "artist": "", "cat": "", "note": "qupu123 未找到页面"}
    except Exception as ex:
        m = {"title": "", "artist": "", "cat": "", "note": "抓取失败:" + type(ex).__name__}
    return s, url, m


def main():
    cache = set()
    if os.path.exists(CACHE):
        for ln in io.open(CACHE, encoding="utf-8"):
            c = ln.rstrip("\n").split("\t")
            if len(c) >= 5 and (c[3].strip() or c[4].strip()):
                cache.add(c[0])
    rows = [l.rstrip("\n").split("\t") for l in io.open(PLAN, encoding="utf-8")][1:]
    todo = [r for r in rows if not r[3]]
    seen, jobs = set(), []
    for r in todo:
        s = r[1]
        if s.split("-", 1)[0] in ("jianpucn", "qupu123", "jianpujia") and s not in cache and s not in seen:
            seen.add(s)
            jobs.append((s, r[0][:-4]))
    print(f"待补 {len(todo)} 份; 要抓 {len(jobs)} 个页面 (已缓存 {len(cache)}), {WORKERS} 线程", flush=True)
    if not jobs:
        return
    g = io.open(CACHE, "a", encoding="utf-8", newline="\n")
    ok = fail = n = 0
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futs = [pool.submit(work, j) for j in jobs]
        for fu in as_completed(futs):
            s, url, m = fu.result()
            n += 1
            hit = bool(m.get("artist") or m.get("cat"))
            ok += hit
            fail += (not hit)
            with _lock:
                g.write("\t".join([s, url, m.get("title", ""), m.get("artist", ""),
                                   m.get("cat", ""), m.get("note", "")]) + "\n")
                g.flush()
            if n % 100 == 0 or n == len(jobs):
                el = time.time() - t0
                print(f"  {n}/{len(jobs)}  有字段 {ok} / 空 {fail}  {el:.0f}s  "
                      f"预计还需 {el / n * (len(jobs) - n) / 60:.1f} 分钟", flush=True)
    g.close()
    print(f"完成: 抓 {len(jobs)} 个, 拿到歌手/分类 {ok}, 空 {fail} -> {CACHE}")


if __name__ == "__main__":
    main()
