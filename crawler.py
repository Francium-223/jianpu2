#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
简谱图片爬虫 —— 支持两个站点：

  1. 歌谱简谱网  http://www.jianpu.cn        (老站, GB2312)
  2. 简谱之家    https://www.jianpujia.com   (帝国CMS, UTF-8)

用法示例:
  # 爬 jianpu.cn 三字歌谱 前 3 页（每页约 30 首）
  python crawler.py jianpucn --cat sanzigepu --pages 3 --out images/jianpucn

  # 爬 jianpu.cn 搜索"青花瓷"
  python crawler.py jianpucn-search --query 青花瓷 --out images/jianpucn-search

  # 爬 jianpujia.com "影视"分类(id=21436) 前 2 页
  python crawler.py jianpujia --list 21436 --pages 2 --out images/jianpujia

  # 爬 jianpujia.com 搜索
  python crawler.py jianpujia-search --query 青花瓷 --out images/jianpujia-search

说明:
  - 每首歌保存为一个子目录: <输出目录>/<歌名>__<站点id>/001.jpg ...
  - 每个子目录里有一个 song.json (标题/来源URL/图片列表)
  - 断点续爬: 已存在的目录会跳过; --delay 控制请求间隔(秒)
"""
import argparse
import json
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

_CTX = None


def ctx():
    global _CTX
    if _CTX is None:
        _CTX = ssl.create_default_context()
        _CTX.check_hostname = False
        _CTX.verify_mode = ssl.CERT_NONE
    return _CTX


def fetch(url, delay=0.3, tries=3, timeout=30):
    """GET with retry. Returns bytes."""
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout, context=ctx()) as r:
                return r.read()
        except Exception as e:
            if i == tries - 1:
                print(f"  ! 下载失败 {url}: {e}", file=sys.stderr)
                return None
            time.sleep(1.5 * (i + 1))
    return None


def post(url, data, delay=0.3, tries=3, timeout=30):
    body = urllib.parse.urlencode(data).encode("utf-8")
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=body, headers={
                "User-Agent": UA,
                "Content-Type": "application/x-www-form-urlencoded",
            })
            with urllib.request.urlopen(req, timeout=timeout, context=ctx()) as r:
                return r.read()
        except Exception as e:
            if i == tries - 1:
                print(f"  ! 请求失败 {url}: {e}", file=sys.stderr)
                return None
            time.sleep(1.5 * (i + 1))
    return None


def sanitize(name, fallback="song"):
    """Windows 文件名安全化。"""
    name = re.sub(r"[<>:\"/\\|?*\x00-\x1f]", "_", name or "")
    name = re.sub(r"\s+", " ", name).strip().strip("._ ")
    return name[:120] or fallback


def save_song(out_dir, site, song_id, title, page_url, img_urls, delay, artist=""):
    """下载一首歌的全部图片到 <out>/<title>__<id>/, 写 song.json。"""
    folder = os.path.join(out_dir, f"{sanitize(title)}__{site}-{song_id}")
    manifest = os.path.join(folder, "song.json")
    if os.path.exists(manifest):
        print(f"  - 已存在, 跳过: {os.path.basename(folder)}")
        return False
    os.makedirs(folder, exist_ok=True)
    files = []
    ok = True
    for i, u in enumerate(img_urls, 1):
        ext = os.path.splitext(urllib.parse.urlparse(u).path)[1] or ".jpg"
        ext = ext.lower()
        if ext not in (".jpg", ".jpeg", ".png", ".gif", ".webp"):
            ext = ".jpg"
        dest = os.path.join(folder, f"{i:03d}{ext}")
        data = fetch(u, delay=delay)
        if data is None or len(data) < 1000:
            print(f"  ! 图片失败: {u}", file=sys.stderr)
            ok = False
            continue
        with open(dest, "wb") as f:
            f.write(data)
        files.append(os.path.basename(dest))
        print(f"  . {os.path.basename(folder)}/{os.path.basename(dest)} ({len(data)//1024} KB)")
        time.sleep(delay)
    with open(manifest, "w", encoding="utf-8") as f:
        json.dump({
            "site": site, "id": song_id, "title": title, "artist": artist,
            "page_url": page_url, "images": files,
        }, f, ensure_ascii=False, indent=2)
    return ok


# ---------------------------------------------------------------- jianpu.cn

JIANPUCN_BASE = "http://www.jianpu.cn"


def jianpucn_decode(data):
    return data.decode("gbk", "ignore")


def jianpucn_parse_list(html, base):
    """返回 (条目列表[(href,title,artist)], 下一页url或None)。"""
    items = []
    for m in re.finditer(r"<a\s+href='(/pu/\d+/\d+\.htm)'[^>]*>\s*\[?([^<\[]+)", html):
        href, title = m.group(1), m.group(2).strip()
        artist = ""
        mm = re.match(r"^([^\]]+)\]\s*(.*)$", title)   # [歌手] 前缀 (正则已吞掉左括号)
        if mm:
            artist, title = mm.group(1).strip(), mm.group(2).strip()
        title = title.replace("&nbsp;", " ").strip()
        items.append((JIANPUCN_BASE + href, title, artist))
    nxt = re.search(r"<a[^>]+href='([^']+)'[^>]*>\s*下一页", html)
    next_url = None
    if nxt:
        next_url = urllib.parse.urljoin(base, nxt.group(1))
    return items, next_url


def jianpucn_parse_detail(html, page_url):
    """返回 (图片绝对URL列表, 歌手)。"""
    m = re.search(r"<div id='jianpu'>(.*?)</div>", html, re.S)
    block = m.group(1) if m else html
    urls = []
    for im in re.finditer(r"<img[^>]+src='([^']+)'", block):
        urls.append(urllib.parse.urljoin(page_url, im.group(1)))
    artist = ""
    am = re.search(r"艺术家/歌手/词曲:\s*<a[^>]*>([^<]+)</a>", html)
    if am:
        artist = am.group(1).strip()
    return urls, artist


def crawl_jianpucn(cat, pages, out, delay):
    base = f"{JIANPUCN_BASE}/{cat}/"
    url = base
    seen_pages = set()
    done, skipped = 0, 0
    for p in range(pages):
        if url in seen_pages:
            break
        seen_pages.add(url)
        print(f"[第{p+1}页] {url}")
        data = fetch(url, delay=delay)
        if data is None:
            break
        html = jianpucn_decode(data)
        items, next_url = jianpucn_parse_list(html, url)
        if not items:
            print("  (本页无条目, 停止)")
            break
        for href, title, list_artist in items:
            detail = jianpucn_decode(fetch(href, delay=delay) or b"")
            if not detail:
                continue
            imgs, artist = jianpucn_parse_detail(detail, href)
            if not imgs:
                print(f"  ! 无图片: {title} {href}", file=sys.stderr)
                continue
            artist = artist or list_artist
            song_id = href.rstrip(".htm").rsplit("/", 1)[-1]
            if save_song(out, "jianpucn", song_id, title, href, imgs, delay, artist):
                done += 1
            else:
                skipped += 1
            time.sleep(delay)
        if not next_url or next_url == url:
            break
        url = next_url
    print(f"完成: 新下载 {done} 首, 跳过 {skipped} 首 -> {out}")


def crawl_jianpucn_search(query, out, delay):
    q = urllib.parse.quote(query.encode("gbk"))
    url = f"{JIANPUCN_BASE}/search?q={q}"
    print(f"[搜索] {url}")
    data = fetch(url, delay=delay)
    if data is None:
        return
    html = jianpucn_decode(data)
    # 搜索表格行: 序号 | 类别 | 标题 | 歌手
    row_re = re.compile(
        r"<tr>\s*<td>\s*\d+\s*</td>\s*<td[^>]*>\s*\[[^\]]+\]\s*</td>\s*"
        r"<td><A href='(\.\./pu/\d+/\d+\.htm)'[^>]*>\s*(?:<font[^>]*>)?([^<]+?)(?:</font>)?</A></td>\s*"
        r"<td>\s*([^<]*?)\s*</td>", re.S)
    links = [(urllib.parse.urljoin(url, m.group(1)), m.group(2).strip(), m.group(3).strip())
             for m in row_re.finditer(html)]
    if not links:  # 兜底: 抓不到表格行时退回旧正则
        raw = re.findall(r"<A href='(\.\./pu/\d+/\d+\.htm)'[^>]*>\s*(?:<font[^>]*>)?([^<]+?)(?:</font>)?</A>", html)
        links = [(urllib.parse.urljoin(url, r), t.strip(), "") for r, t in raw]
    if not links:
        print("  (未找到结果)", file=sys.stderr)
        return
    done = 0
    for href, raw_title, artist in links:
        title = re.sub(r"^[^\]]*\]\s*", "", raw_title.strip())
        detail = jianpucn_decode(fetch(href, delay=delay) or b"")
        if not detail:
            continue
        imgs, detail_artist = jianpucn_parse_detail(detail, href)
        if not imgs:
            continue
        artist = detail_artist or artist
        song_id = href.rstrip(".htm").rsplit("/", 1)[-1]
        if save_song(out, "jianpucn", song_id, title.strip(), href, imgs, delay, artist):
            done += 1
        time.sleep(delay)
    print(f"完成: 新下载 {done} 首 -> {out}")


# ------------------------------------------------------------- jianpujia.com

JIANPUJIA_BASE = "https://www.jianpujia.com"


def jianpujia_parse_list(html, base):
    items = []
    for m in re.finditer(r'<li><a href="(/(?:jianpu|gangqinpu|jitapu|youkelilipu|erhu|dizu|hulusi|sax|dianziqin|shoufengqin|xiaotiqin|guzheng|pipa|zhongruan|yangqin|errenzhuan|pingju|yueju|huangmeixi|jingju|qita|jiaoxue|zongpu)/\d+\.html)"[^>]*>(.*?)</a></li>', html):
        href, title = m.group(1), m.group(2)
        title = re.sub(r"<[^>]+>", "", title).strip()
        items.append((JIANPUJIA_BASE + href, title))
    # 去重保序
    seen, uniq = set(), []
    for it in items:
        if it[0] not in seen:
            seen.add(it[0])
            uniq.append(it)
    return uniq


SINGER_STOP = {"女声", "男声", "童声", "合唱", "独唱", "对唱", "原唱", "翻唱",
               "现场", "伴奏", "演奏", "演唱", "齐唱", "领唱", "女生", "男生",
               "少儿", "儿歌", "动画", "电影", "插曲", "主题曲", "片尾曲",
               "片头曲", "纯音乐", "钢琴", "吉他", "小提琴", "琵琶", "二胡"}


def jianpujia_parse_detail(html):
    """返回 (图片URL列表, 歌手[启发式])。"""
    m = re.search(r'<div[^>]*class="article_content"[^>]*>(.*?)</div>\s*</div>', html, re.S)
    block = m.group(1) if m else html
    urls = []
    for im in re.finditer(r'<img[^>]+src="(https?://[^"]+\.(?:png|jpe?g|gif|webp))"', block, re.I):
        u = im.group(1)
        if "logo" in u or "qrimg" in u:
            continue
        urls.append(u)
    artist = ""
    am = re.search(r"([\u4e00-\u9fa5A-Za-z0-9·]{1,8})演唱", html)
    if am and am.group(1) not in SINGER_STOP:
        artist = am.group(1)
    else:
        am2 = re.search(r"演唱[：:]?\s*([\u4e00-\u9fa5A-Za-z0-9·]{1,8})", html)
        if am2 and am2.group(1) not in SINGER_STOP:
            artist = am2.group(1)
    return urls, artist


def crawl_jianpujia(list_id, pages, out, delay):
    done, skipped = 0, 0
    seen_ids = set()
    for p in range(pages):
        url = f"{JIANPUJIA_BASE}/list/{list_id}-{p}.html"
        print(f"[第{p+1}页] {url}")
        data = fetch(url, delay=delay)
        if data is None:
            break
        html = data.decode("utf-8", "ignore")
        items = jianpujia_parse_list(html, url)
        new_items = [it for it in items if it[0] not in seen_ids]
        if not new_items:
            print("  (无新条目, 停止)")
            break
        for href, title in new_items:
            seen_ids.add(href)
            detail_html = (fetch(href, delay=delay) or b"").decode("utf-8", "ignore")
            if not detail_html:
                continue
            imgs, artist = jianpujia_parse_detail(detail_html)
            if not imgs:
                print(f"  ! 无图片: {title} {href}", file=sys.stderr)
                continue
            song_id = href.rstrip(".html").rsplit("/", 1)[-1]
            if save_song(out, "jianpujia", song_id, title, href, imgs, delay, artist):
                done += 1
            else:
                skipped += 1
            time.sleep(delay)
    print(f"完成: 新下载 {done} 首, 跳过 {skipped} 首 -> {out}")


def crawl_jianpujia_search(query, out, delay):
    data = post(f"{JIANPUJIA_BASE}/e/search/index.php", {
        "keyboard": query, "show": "title", "tempid": "1",
        "tbname": "news", "mid": "1", "dopost": "search",
    }, delay=delay)
    if data is None:
        return
    html = data.decode("utf-8", "ignore")
    links = re.findall(r'<a href="(/(?:jianpu|gangqinpu|jitapu|youkelilipu)/\d+\.html)"[^>]*>(.*?)</a>', html, re.S)
    if not links:
        print("  (未找到结果)", file=sys.stderr)
        return
    done = 0
    seen = set()
    for rel, title in links:
        href = JIANPUJIA_BASE + rel
        if href in seen:
            continue
        seen.add(href)
        title = re.sub(r"<[^>]+>", "", title).strip()
        detail_html = (fetch(href, delay=delay) or b"").decode("utf-8", "ignore")
        if not detail_html:
            continue
        imgs, artist = jianpujia_parse_detail(detail_html)
        if not imgs:
            continue
        song_id = href.rstrip(".html").rsplit("/", 1)[-1]
        if save_song(out, "jianpujia", song_id, title, href, imgs, delay, artist):
            done += 1
        time.sleep(delay)
    print(f"完成: 新下载 {done} 首 -> {out}")


# --------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="简谱图片爬虫 (jianpu.cn / jianpujia.com)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p1 = sub.add_parser("jianpucn", help="爬 jianpu.cn 分类列表")
    p1.add_argument("--cat", required=True, help="分类名, 如 sanzigepu/erzigepu/jitapu/... (首页分类链接最后一段)")
    p1.add_argument("--pages", type=int, default=3, help="爬多少页 (默认3)")
    p1.add_argument("--out", default="images/jianpucn")
    p1.add_argument("--delay", type=float, default=0.3)

    p2 = sub.add_parser("jianpucn-search", help="按关键词搜索 jianpu.cn")
    p2.add_argument("--query", required=True)
    p2.add_argument("--out", default="images/jianpucn-search")
    p2.add_argument("--delay", type=float, default=0.3)

    p3 = sub.add_parser("jianpujia", help="爬 jianpujia.com 分类列表 (帝国CMS list id)")
    p3.add_argument("--list", dest="list_id", required=True, help="分类列表ID, 如 21436(影视)/3462(儿歌)/583(周杰伦)")
    p3.add_argument("--pages", type=int, default=3)
    p3.add_argument("--out", default="images/jianpujia")
    p3.add_argument("--delay", type=float, default=0.3)

    p4 = sub.add_parser("jianpujia-search", help="按关键词搜索 jianpujia.com")
    p4.add_argument("--query", required=True)
    p4.add_argument("--out", default="images/jianpujia-search")
    p4.add_argument("--delay", type=float, default=0.3)

    a = ap.parse_args()
    if a.cmd == "jianpucn":
        crawl_jianpucn(a.cat, a.pages, a.out, a.delay)
    elif a.cmd == "jianpucn-search":
        crawl_jianpucn_search(a.query, a.out, a.delay)
    elif a.cmd == "jianpujia":
        crawl_jianpujia(a.list_id, a.pages, a.out, a.delay)
    elif a.cmd == "jianpujia-search":
        crawl_jianpujia_search(a.query, a.out, a.delay)


if __name__ == "__main__":
    main()
