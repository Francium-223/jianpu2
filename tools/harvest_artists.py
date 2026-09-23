#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从原谱站页面抽**歌手**(以及 jianpujia 的分类), 给语料补 usertag。

为什么需要: `todo=add tags` 剩 1150 首, 其中 jianpucn 901 首——该站**没有流派分类**
(面包屑只给"三字歌谱"这种字数分类), 但页面标题里按 `<歌名> <歌手> 歌谱简谱网` 排了歌手,
jianpujia 则是 `<歌名>…_<歌手>演唱_…`。歌手正是本仓库在用的标签形态(已有 邓丽君 392 / 阎维文 292 …)。

抽取规则(都在页面 <title> 上, 不靠猜):
  * jianpucn : 去掉站名后缀 -> 去掉语料里的 `title` 前缀 -> 剩下的就是歌手
  * jianpujia: 标题里 `…_<歌手>演唱_…` 的 `<歌手>`;  分类取页面 `分类：X` 或 keywords 首段

安全: 候选要过长→宽→停用词三道过滤; 结果先落 `_analysis/artist_proposal.tsv` 供人看,
`--apply` 才写进曲谱(只追加 usertag, 不动其它字段)。抓到的东西按 source 缓存, 可断点续跑。

用法:
  python3 jianpu2/tools/harvest_artists.py --limit 30        # 小样
  python3 jianpu2/tools/harvest_artists.py                   # 全量(约 4000 页)
  python3 jianpu2/tools/harvest_artists.py --apply           # 把提案写进 scores/*.txt
"""
import argparse
import collections
import concurrent.futures as cf
import io
import json
import os
import re
import ssl
import sys
import threading
import time
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) jianpu-corpus-artist/1.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
CACHE = os.path.join(ROOT, "train-work", "artist_cache")
OUT = os.path.join(WS, "_analysis", "artist_proposal.tsv")
sys.stdout.reconfigure(encoding="utf-8")

SITE_SUFFIX = re.compile(r"\s*(歌谱简谱网|简谱之家|中国曲谱网|免费下载).*$")
# 明显不是歌手的词
STOP = {"扫描版", "原唱", "群星", "佚名", "未知", "简谱", "曲谱", "歌谱", "演唱", "钢琴",
        "吉他", "合唱", "伴奏", "纯音乐", "儿歌", "民歌", "通俗", "美声", "版", "演唱者",
        "少儿合唱", "童声", "女声", "男声", "合唱团", "合唱队", "乐队", "网络歌手", "歌曲类"}
# 站点词/标题词: 候选里只要含这些, 就不是人名(实测 jianpucn 的 `发烧 歌曲类 简谱 …`、
# jianpujia 的 `纸上雪简谱歌词_许嵩…` 会漏出这种)
SITE_WORDS = ("简谱", "歌谱", "曲谱", "歌曲类", "五线谱", "钢琴谱", "吉他谱", "演唱", "歌词",
              "扫描", "免费下载", "记谱", "制谱", "专辑", "原版", "弹唱", "指弹")
_lock = threading.Lock()


def sslctx():
    try:
        return ssl.create_default_context()
    except Exception:
        return ssl._create_unverified_context()


def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "zh-CN"})
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=sslctx()) as r:
            return r.status, r.read(300000)
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:
        return 0, str(e).encode()


def decode(raw, site):
    for enc in (("gb18030", "utf-8") if site == "jianpucn" else ("utf-8", "gb18030")):
        try:
            return raw.decode(enc, "ignore")
        except Exception:
            pass
    return raw.decode("utf-8", "ignore")


def page_title(html):
    m = re.search(r"<title[^>]*>(.*?)</title>", html or "", re.S | re.I)
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def clean_name(s):
    s = re.sub(r"[（(【\[].*?[）)】\]]", " ", s or "")
    s = re.sub(r"\s+", " ", s).strip(" _-·—,，、;；:：/\\")
    return s.strip()


def plausible(name, title):
    if not name or len(name) < 2 or len(name) > 16:
        return False
    if name in STOP or name == title:
        return False
    if re.search(r"[0-9=（）()【】\[\]]", name):
        return False
    if any(w in name for w in SITE_WORDS):
        return False
    return bool(re.search(r"[\u4e00-\u9fa5A-Za-z]", name))


def artist_from_jianpucn(ptitle, title):
    t = SITE_SUFFIX.sub("", ptitle)
    if title and title in t:
        return clean_name(t.split(title, 1)[1])
    return ""


def artist_from_jianpujia(ptitle):
    """jianpujia 的标题形如 `<歌名>[（歌词）]简谱_<歌手>演唱_<词曲>-免费下载-简谱之家`。

    ⚠ 两个坑(都实测踩过):
      ① 页面把空格写成了 `_`, 多人合作会被截断(`Hans Zimmer&amp;Klaus Badelt演唱` 只抽到 `Badelt`)
         -> 先把 `_` 还原成空格;
      ② 有的标题是 `你怎么说简谱(歌词)_邓丽君演唱_…`, 直接取"演唱"前面那段会把**歌名**也带上
         -> 再按最后一个 `简谱` / `)` 切一刀, 只留人名。
    """
    t = ptitle.replace("_", " ")
    m = re.search(r"([^_]{2,80}?)\s*演唱", t)
    seg = m.group(1) if m else ""
    for sep in ("简谱", "歌词", ")"):
        if sep in seg:
            seg = seg.rsplit(sep, 1)[1]
    seg = seg.replace("&amp;", "&").replace("&nbsp;", " ")
    return clean_name(seg)


# jianpujia 的"分类"字段有时填的是歌手(实测 `分类：许嵩`), 所以只认**语料里已有的分类词**
KNOWN_CATS = {"儿歌", "民歌", "通俗歌曲", "合唱", "美声", "草原", "钢琴谱", "记谱", "影视",
              "谱友上传", "外国歌曲", "原创", "戏曲", "器乐", "进行曲", "口琴谱", "二胡谱",
              "萨克斯谱", "古筝谱", "琵琶谱", "笛子谱", "小提琴谱", "吉他谱"}


def category_from_jianpujia(html):
    """页面里是 `相关栏目：<a href="/list/62">草原</a>` —— 名字在锚文本里, 不是在冒号后面。"""
    html = html or ""
    for pat in (r"相关栏目[：:]\s*<a[^>]*>([^<]{2,12})</a>",
                r"(?:分类|栏目|类型)[：:]\s*(?!<)([^<\n]{2,12})"):
        m = re.search(pat, html)
        if m:
            c = clean_name(m.group(1))
            if c in KNOWN_CATS:
                return c
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--sites", default="jianpucn,jianpujia")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--interval", type=float, default=0.25)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--reparse", action="store_true",
                    help="不联网: 用缓存里的 page_title 重新跑一遍抽取规则(改了规则后重算)")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    sp = json.load(open(os.path.join(DB, "source_pages.json"), encoding="utf-8"))
    sites = set(x.strip() for x in a.sites.split(",") if x.strip())
    # 目标: 有核对过页面的曲; 已缓存结果的跳过
    os.makedirs(CACHE, exist_ok=True)
    cache = {}
    cpath = os.path.join(CACHE, "artists.json")
    if os.path.isfile(cpath):
        cache = json.load(open(cpath, encoding="utf-8"))
    if a.reparse:
        # 不联网: 用缓存里的 page_title 重跑抽取规则(改了规则时用), 顺便把旧的错误值清掉
        n = 0
        for rec in cache.values():
            pt = rec.get("page_title") or ""
            rec["artist"] = ""
            rec["category"] = ""
            if pt:
                cand = (artist_from_jianpucn(pt, rec.get("title", ""))
                        if rec.get("site") == "jianpucn" else artist_from_jianpujia(pt))
                if plausible(cand, rec.get("title", "")):
                    rec["artist"] = cand
                    n += 1
        json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
        print("离线重解析完成: %d 条缓存, 抽到歌手 %d 个" % (len(cache), n))
        if not a.apply:
            return 0
    todo = []
    for fn in sorted(os.listdir(SCORES)):
        if not fn.endswith(".txt") or fn.endswith(("_expand.txt", "_buf.txt")):
            continue
        head = io.open(os.path.join(SCORES, fn), encoding="utf-8", errors="replace").read().split("%--", 1)[0]
        m = re.search(r"(?m)^source=(\S+)", head)
        src = m.group(1) if m else ""
        if not src or src.split("-")[0] not in sites or src not in sp:
            continue
        if src in cache:
            continue
        t = re.search(r"(?m)^title=(.*)$", head)
        todo.append((fn, src, (t.group(1).strip() if t else ""), sp[src]["url"]))
    if a.limit:
        todo = todo[:a.limit]
    print("待抓 %d 个页面(缓存里已有 %d 条); 站点 %s" % (len(todo), len(cache), sorted(sites)), flush=True)

    host_last, host_lock = {}, {}
    def polite(url, interval):
        host = urllib.parse.urlsplit(url).netloc
        with _lock:
            lk = host_lock.setdefault(host, threading.Lock())
        with lk:
            w = interval - (time.time() - host_last.get(host, 0))
            if w > 0:
                time.sleep(w)
            host_last[host] = time.time()

    t0 = time.time()
    def work(item):
        fn, src, title, url = item
        site = src.split("-")[0]
        polite(url, a.interval)
        code, raw = fetch(url)
        rec = {"site": site, "url": url, "code": code, "title": title, "file": fn,
               "artist": "", "category": "", "page_title": ""}
        if code == 200 and raw:
            html = decode(raw, site)
            pt = page_title(html)
            rec["page_title"] = pt
            cand = artist_from_jianpucn(pt, title) if site == "jianpucn" else artist_from_jianpujia(pt)
            if plausible(cand, title):
                rec["artist"] = cand
            if site == "jianpujia":
                rec["category"] = category_from_jianpujia(html)
        with _lock:
            cache[src] = rec
            if len(cache) % 50 == 0:
                json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
        return rec

    with cf.ThreadPoolExecutor(max_workers=a.workers) as ex:
        list(ex.map(work, todo))
    json.dump(cache, open(cpath, "w", encoding="utf-8"), ensure_ascii=False)
    print("抓完, 用时 %.1f 分钟" % ((time.time() - t0) / 60), flush=True)

    # 出提案
    rows = []
    for src, rec in sorted(cache.items()):
        if rec.get("artist") or rec.get("category"):
            rows.append((rec.get("file", ""), rec["title"], src, rec["site"],
                         rec.get("artist", ""), rec.get("category", ""),
                         rec.get("page_title", "")[:80]))
    with io.open(a.out, "w", encoding="utf-8", newline="\n") as g:
        g.write("file\ttitle\tsource\tsite\tartist\tcategory\tpage_title\n")
        for r in rows:
            g.write("\t".join(r) + "\n")
    st = collections.Counter(r[3] for r in rows)
    print("提案: %s (%d 条)  按站点: %s" % (a.out, len(rows), dict(st)))
    print("   有歌手: %d;  有分类(jianpujia): %d"
          % (sum(1 for r in rows if r[4]), sum(1 for r in rows if r[5])))

    if a.apply:
        sys.path.insert(0, HERE)
        from propose_tags import add_tag           # 同一份"写进曲谱"的实现, 不复制
        n_add = n_ex = 0
        for fn, _t, _s, _site, artist, cat, _pt in rows:
            if not fn:
                continue
            for tag in [x for x in (artist, cat) if x]:
                try:
                    r = add_tag(os.path.join(SCORES, fn), tag, clear_todo=tag.startswith('分类/'))
                    n_add += (r == "added")
                    n_ex += (r == "exists")
                except Exception as e:
                    print("  ! %s: %s" % (fn, e))
        print("已写入 %d 条标签(已存在 %d 条)。记得跑 parse_scores.py 重建索引。" % (n_add, n_ex))
    return 0


if __name__ == "__main__":
    sys.exit(main())
