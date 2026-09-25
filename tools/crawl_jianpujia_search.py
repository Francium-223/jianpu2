#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按**曲名搜 jianpujia** 并下谱图 —— 用来补金曲缺口里 jianpu.cn 没有的那些。

为什么需要它: jianpu.cn 只能"按字数分类逐页扫目录"（`crawl_jianpucn_by_title.py`），
扫到 1400 页还找不到就没了；而 **jianpujia 有可用的站内搜索**（EmpireCMS）：

    POST https://www.jianpujia.com/e/search/index.php   show=title & keyboard=<曲名>
      -> 302 到 /e/search/result/?searchid=N，页面里是 `/jianpu/<id>.html` + 标题

谱图在曲谱页里，形如 `https://image.jianpujia.com/jianpudq/jianpu40/<hash>.png`（一首 1~3 张）。

用法:
    python3 tools/crawl_jianpujia_search.py "最后一夜@蔡琴,天天天蓝@潘越云"
    python3 tools/crawl_jianpujia_search.py "最后一夜@蔡琴" --per 3 --dry

口径:
  * `曲名@歌手` —— 歌手可选；给了就只在标题里含该歌手的候选中优先取。
  * 命中判据: 归一化后**结果标题以目标曲名开头**（短标题 <=3 字要求更严：完全相等才算前缀命中），
    避免《最后一夜》匹到《陪你最后一夜》这种。
  * 只下谱图，**不碰语料**；图落 `JIANPU_IMAGES` 或 `<工作区>/images-prep/jianpujia-title/`。
  * 同目录已存在就跳过（断点续跑）；每次请求之间 sleep。
"""
import argparse
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
sys.path.insert(0, HERE)
import tlsfetch                                              # noqa: E402

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or os.path.join(WS, "images-prep")
OUT = os.path.join(IMG_ROOT, "jianpujia-title")
SCANLOG = os.path.join(ROOT, "train-work", "jianpujia_search_scan.tsv")
ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")


def norm(s):
    return DROP.sub("", ENT.sub("", s or "")).casefold()


def safe(s):
    s = ENT.sub("", s)
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


def post(url, data, referer):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        "User-Agent": UA, "Referer": referer,
        "Content-Type": "application/x-www-form-urlencoded"})
    with tlsfetch.urlopen(req, timeout=25) as r:
        return r.geturl(), r.read().decode("utf-8", "replace")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "https://www.jianpujia.com/"})
    with tlsfetch.urlopen(req, timeout=25) as r:
        return r.read()


def search(title, sleep):
    """-> [(id, 标题), ...]"""
    url, h = post("https://www.jianpujia.com/e/search/index.php",
                  {"show": "title", "keyboard": title},
                  "https://www.jianpujia.com/search/")
    time.sleep(sleep)
    out, seen = [], set()
    for m in re.finditer(r'href=["\'](/jianpu/(\d+)\.html)["\'][^>]*>(.*?)</a>', h, re.S | re.I):
        sid, txt = m.group(2), re.sub(r"<[^>]+>", "", m.group(3)).strip()
        if not txt or sid in seen:
            continue
        seen.add(sid)
        out.append((sid, txt))
    return url, out


ARRANGE = re.compile(r"钢琴|吉他|尤克里里|弹唱|指弹|伴奏|弹奏|电子琴|双排键|四手|独奏|合奏")


def pick(title, artist, cands):
    """挑出"结果标题以目标曲名开头"的候选；给了歌手就**必须**含该歌手；
    并且**优先要"简谱"而不是钢琴/吉他改编谱**。

    2026-09-25 实测踩过两件事:
      1. 第一版在"给了歌手但没一个候选含它"时**退回全部前缀命中**, 于是 `天籁@关正杰` 把
         《天籁简谱_叶子演唱》当命中、`小三@丁禹兮` 把《小三前传》当命中 —— 4 个错谱被下下来。
         现在: 给了歌手而无人匹配 -> 只接受**标题完全相同**的候选, 否则算没命中。
      2. 第一版按搜索结果原序取前 N 个, 结果《最后一夜》先取到了**钢琴谱**。语料口径是
         **改编不收**(`queue_from_crawl.py` 会把带"钢琴/吉他…"的判成改编), 所以这里把
         简谱排在改编前面 —— 否则补回来的缺口仍然进不了语料。
    """
    nt, na = norm(title), norm(artist)
    hits = [c for c in cands if norm(c[1]).startswith(nt)]
    if na:
        witha = [c for c in hits if na in norm(c[1])]
        hits = witha if witha else [c for c in hits if norm(c[1]) == nt]
    # 稳定排序: 非改编在前
    return sorted(hits, key=lambda c: 1 if ARRANGE.search(c[1]) else 0)


def score_images(html):
    imgs = re.findall(r'https://image\.jianpujia\.com/[^"\'\s>]+?\.(?:png|jpg|jpeg|gif)', html, re.I)
    out, seen = [], set()
    for u in imgs:
        if u not in seen:
            seen.add(u)
            out.append(u)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("targets", help="逗号分隔；每项 `曲名` 或 `曲名@歌手`")
    ap.add_argument("--per", type=int, default=3, help="每首最多下几个谱页(默认 3)")
    ap.add_argument("--sleep", type=float, default=1.5, help="每次请求之间的间隔(秒)")
    ap.add_argument("--dry", action="store_true", help="只搜不下")
    a = ap.parse_args()

    targets = []
    for t in a.targets.split(","):
        t = t.strip()
        if not t:
            continue
        name, _, artist = t.partition("@")
        targets.append((name.strip(), artist.strip()))
    if not targets:
        print("没给曲名")
        return 2

    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(SCANLOG), exist_ok=True)
    log = io.open(SCANLOG, "a", encoding="utf-8")

    total_hits = total_pages = 0
    for name, artist in targets:
        print("=== %s%s" % (name, (" @ " + artist) if artist else ""), flush=True)
        try:
            url, cands = search(name, a.sleep)
        except Exception as e:
            print("    搜索失败: %s %s" % (type(e).__name__, str(e)[:70]), flush=True)
            continue
        print("    结果 %d 条 (%s)" % (len(cands), url[:60]), flush=True)
        hits = pick(name, artist, cands)
        if not hits and artist:
            # **按歌手兜底**: 曲名搜不到时, 改用歌手当关键词, 再在结果里按曲名找。
            # 为什么有用: 站点标题常是"曲名+描述+歌手", 而曲名本身可能带括号/副标题(如《落（花开花落日生日没）》),
            # 直接搜曲名会 0 条; 搜歌手却能把他的谱全列出来, 目标就在里面。
            try:
                url2, cands2 = search(artist, a.sleep)
                print("    曲名 0 命中 -> 改搜歌手「%s」: %d 条" % (artist, len(cands2)), flush=True)
                hits = pick(name, "", cands2)
                if hits:
                    print("    按歌手找到 %d 个谱页" % len(hits), flush=True)
                else:
                    for sid, txt in cands2[:5]:
                        print("      (该歌手候选) %-34s %s" % (txt[:34], sid), flush=True)
            except Exception as e:
                print("    按歌手兜底失败: %s" % type(e).__name__, flush=True)
        if not hits:
            for sid, txt in cands[:3]:
                print("      (候选) %-34s %s" % (txt[:34], sid), flush=True)
            continue
        total_hits += 1
        print("    命中 %d 个谱页" % len(hits), flush=True)
        for sid, txt in hits[:a.per]:
            d = os.path.join(OUT, "%s__jianpujia-%s" % (safe(txt), sid))
            log.write("%s\t%s\t%s\t%s\n" % (name, txt, sid, "skip" if os.path.isdir(d) and os.listdir(d) else "get"))
            log.flush()
            if os.path.isdir(d) and os.listdir(d):
                print("      = 已有 %s" % os.path.basename(d)[:44], flush=True)
                continue
            if a.dry:
                print("      (dry) 会下 %s" % txt[:44], flush=True)
                continue
            try:
                page = get("https://www.jianpujia.com/jianpu/%s.html" % sid).decode("utf-8", "replace")
            except Exception as e:
                print("      ✗ 曲谱页取不到: %s" % type(e).__name__, flush=True)
                continue
            time.sleep(a.sleep)
            imgs = score_images(page)
            if not imgs:
                print("      ✗ 页面里没找到谱图", flush=True)
                continue
            os.makedirs(d, exist_ok=True)
            n = 0
            for u in imgs[:5]:
                ext = os.path.splitext(urllib.parse.urlsplit(u).path)[1] or ".png"
                try:
                    with open(os.path.join(d, "%03d%s" % (n + 1, ext)), "wb") as g:
                        g.write(get(u))
                    n += 1
                except Exception as e:
                    print("      ✗ 图下载失败: %s" % type(e).__name__, flush=True)
                time.sleep(a.sleep)
            if n:
                total_pages += 1
                print("      + %s (%d 张)" % (txt[:40], n), flush=True)

    log.close()
    print("\n完成: %d/%d 首有命中, 下载 %d 个谱页 -> %s" % (total_hits, len(targets), total_pages, OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
