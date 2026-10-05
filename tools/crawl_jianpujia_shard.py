# -*- coding: utf-8 -*-
"""jianpujia(简谱之家)**按 id 分片**的存量抓取器 —— 独立分片 / 独立状态 / 硬止损。

为什么不直接用 `crawl_jianpujia.py`:
  ① 它**没有走 `crawl_limits.throttle()`** —— 图与图之间只 `sleep(0.15)`、每首 `sleep(0.25)`,
     实测一首 3 图的谱 ≈ 0.7 秒发 4 个请求, 打破"单站礼貌限速 >=1 秒/请求"这条铁律
     (本文件一律走 `throttle()`, 且 `JIANPU_RATE` 只能调慢)。
  ② 它一次只吃一个 id 列表, 没有分片、没有独立状态文件 —— 多个 worker 无法各管一段、断点续爬。
  ③ 它没有"逐首查磁盘止损"; 抓满盘会把同一条流水线一起写死。

分片口径: 第 `--shard k`(0-based) 个 worker 走 `id ≡ k (mod --shards)` 的那些 id。
这样 k 个 worker 的 id 集合**互不相交**, 且各自 `>=1 秒/请求`, 站点看到的是 k 条互不相干的礼貌流
(纪律: 单站并发 worker <=3; 提并行靠多 IP, 不靠对同一站加压)。

用法:
    # 1) 先量底: 探测 id 段命中率(只发请求, 不下载)
    py -3.13 tools/crawl_jianpujia_shard.py --probe --start 157000 --end 157300

    # 2) 分片抓: 3 个 worker 各管一段, 各自独立状态文件
    py -3.13 tools/crawl_jianpujia_shard.py --shard 0 --shards 3 --start 150000 --end 200000 --quota 200
    py -3.13 tools/crawl_jianpujia_shard.py --shard 1 --shards 3 --start 150000 --end 200000 --quota 200
    py -3.13 tools/crawl_jianpujia_shard.py --shard 2 --shards 3 --start 150000 --end 200000 --quota 200
"""
import argparse
import glob
import io
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from guard import guard_help                      # noqa: E402
guard_help(__doc__)

from crawl_limits import throttle                  # noqa: E402  >=1 秒/请求(唯一实现)
from crawl_disk_guard import check, min_free_gib   # noqa: E402  硬止损(25 GiB, 不可下调)
from jp_root import ROOT, images_root              # noqa: E402  图库唯一口径

sys.stdout.reconfigure(encoding="utf-8")

BASE = "http://www.jianpujia.com"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
IMG_RE = re.compile(r"""<img[^>]+\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))""", re.I)
H1_RE = re.compile(r"<h1[^>]*>(.*?)</h1>", re.S | re.I)
TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S | re.I)


def log_open(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return io.open(path, "a", encoding="utf-8", buffering=1)


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


def fetch(url, binary=False, timeout=25, log=None):
    """唯一网络出口 —— 每个请求**前**都过 `throttle()`(>=1 秒/请求)。"""
    throttle()
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        if log is not None:
            log.write("%d\t%d\tHTTP %s\n" % (int(time.time()), 0, e.code))
        return None
    return raw if binary else raw.decode("utf-8", errors="replace")


def img_of(html):
    out = []
    for m in IMG_RE.finditer(html):
        u = m.group(1) or m.group(2) or m.group(3) or ""
        if "image.jianpujia.com" not in u.lower():
            continue
        if u not in out:
            out.append(u)
    return out


def song_title(html, sid):
    m = H1_RE.search(html) or TITLE_RE.search(html)
    raw = re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""
    raw = re.split(r"简谱", raw)[0].strip()
    t = safe(raw)
    return t if t else "untitled-%s" % sid


def corpus():
    try:
        import corpus_index
        return corpus_index
    except Exception as e:
        print("  [语料索引不可用, 按老办法抓] %s: %s" % (type(e).__name__, e), flush=True)
        return None


def read_state(p):
    """独立状态文件: 一行 `last_id\tok\tn_imgs\tbytes`。损坏就从头(不赌)。"""
    if not os.path.exists(p):
        return 0, 0, 0, 0
    try:
        f = io.open(p, encoding="utf-8").read().split("\t")
        return int(f[0]), int(f[1]), int(f[2]), int(f[3])
    except Exception:
        return 0, 0, 0, 0


def write_state(p, last, ok, n, nb):
    """**原子写**(.part -> os.replace): 被硬止损直接杀进程时不留半个状态文件。"""
    t = p + ".part"
    with io.open(t, "w", encoding="utf-8") as g:
        g.write("%d\t%d\t%d\t%d\n" % (last, ok, n, nb))
    os.replace(t, p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=int, required=True, help="id 段起点(含)")
    ap.add_argument("--end", type=int, required=True, help="id 段终点(含)")
    ap.add_argument("--shard", type=int, default=0, help="第几片(0-based)")
    ap.add_argument("--shards", type=int, default=1, help="共几片")
    ap.add_argument("--quota", type=int, default=200, help="本片本次最多新下几首")
    ap.add_argument("--out", default="", help="图库子目录(默认 images-prep/jianpujia-shard)")
    ap.add_argument("--state", default="", help="状态文件(默认 train-work/jianpujia_shard<k>.tsv)")
    ap.add_argument("--tag", default="", help="日志标签(默认 shard<k>)")
    ap.add_argument("--probe", action="store_true",
                    help="只探测 id 命中率(逐 id 发请求、不下图、写 id 区间分桶统计)")
    ap.add_argument("--max-min", type=float, default=0, help="本次最多跑几分钟(0=不限)")
    a = ap.parse_args()

    if a.shards < 1 or not (0 <= a.shard < a.shards):
        print("--shard 必须落在 [0, --shards) 内")
        return 2
    if a.end < a.start:
        print("--end 必须 >= --start")
        return 2
    tag = a.tag or ("probe" if a.probe else "shard%d" % a.shard)
    OUT_ROOT = images_root()
    OUT = a.out or os.path.join(OUT_ROOT, "jianpujia-shard")
    STATE = a.state or os.path.join(ROOT, "train-work", "jianpujia_shard%d.tsv" % a.shard)
    LOG = os.path.join(OUT_ROOT, "_logs", "jianpujia_%s.log" % tag)
    log = log_open(LOG)
    os.makedirs(OUT, exist_ok=True)

    t0 = time.time()

    def say(m):
        line = "[%s %s] %s" % (time.strftime("%H:%M:%S"), tag, m)
        print(line, flush=True)
        log.write(line + "\n")

    say("id 段 %d..%d 片 %d/%d 配额 %d 图库 %s" % (a.start, a.end, a.shard, a.shards, a.quota, OUT))
    say("限速 >=1 秒/请求(crawl_limits)  止损线 %.1f GiB  状态 %s" % (min_free_gib(), STATE))

    ok0, free0, msg0 = check(OUT_ROOT)
    say("磁盘: " + msg0)
    if not ok0:
        say("!! 低于止损线, 拒绝启动")
        return 3

    # ── id 序列: 片 k 走 id ≡ k (mod shards) ─────────────────────────────────
    ids = [i for i in range(a.start, a.end + 1) if (i - a.start) % a.shards == a.shard]

    if a.probe:
        buckets = {}
        n200 = n404 = nother = 0
        for k, sid in enumerate(ids, 1):
            if a.max_min and (time.time() - t0) > a.max_min * 60:
                say("到 --max-min, 收工")
                break
            b = (sid // 10000) * 10000
            st = "404"
            try:
                throttle()
                req = urllib.request.Request("%s/jianpu/%d.html" % (BASE, sid),
                                             headers={"User-Agent": UA, "Referer": BASE + "/"})
                with urllib.request.urlopen(req, timeout=20) as r:
                    st = "200"
            except urllib.error.HTTPError as e:
                st = str(e.code)
            except Exception:
                st = "ERR"
            if st == "200":
                n200 += 1
                buckets[b] = buckets.get(b, 0) + 1
            elif st == "404":
                n404 += 1
            else:
                nother += 1
            if k % 50 == 0:
                say("  探测 %d/%d  200=%d 404=%d 其他=%d  用时 %.0fs"
                    % (k, len(ids), n200, n404, nother, time.time() - t0))
        tot = n200 + n404 + nother
        el = time.time() - t0
        say("探测完成: %d 个 id, 200=%d (%.1f%%) 404=%d 其他=%d, 用时 %.0fs (%.2f 请求/秒)"
            % (tot, n200, 100.0 * n200 / max(tot, 1), n404, nother, el, tot / max(el, 1e-9)))
        say("按 1 万 id 分桶命中: " + "  ".join("%d:%d" % (k, buckets[k]) for k in sorted(buckets)))
        log.close()
        return 0

    last, ok, n_imgs, n_bytes = read_state(STATE)
    if last:
        ids = [i for i in ids if i > last]
        say("续爬: 从状态文件跳过 id <= %d, 剩 %d 个" % (last, len(ids)))

    ci = corpus()
    skipped = ci.SkipCounter() if ci is not None else None
    fails = {}
    n404 = n_dup = n_new = n_big = 0
    stop_reason = ""

    for k, sid in enumerate(ids, 1):
        if n_new >= a.quota:
            stop_reason = "到配额 %d" % a.quota
            break
        if a.max_min and (time.time() - t0) > a.max_min * 60:
            stop_reason = "到 --max-min"
            break
        if k % 20 == 0:
            okf, freef, msgf = check(OUT_ROOT)
            if not okf:
                say("!! " + msgf + " -> 立即收工")
                stop_reason = "磁盘止损"
                break
        ph = fetch("%s/jianpu/%d.html" % (BASE, sid))
        if ph is None:
            n404 += 1
            continue
        title = song_title(ph, sid)
        if ci is not None:
            r = ci.skip_reason("jianpujia", str(sid), title)
            if r:
                skipped.count(r)
                if r == "title":
                    skipped.note_title_skip(title[:44])
                n_dup += 1
                write_state(STATE, sid, ok, n_imgs, n_bytes)
                continue
        d = os.path.join(OUT, "%s__jianpujia-%d" % (safe(title), sid))
        if os.path.isdir(d) and any(f.lower().endswith((".jpg", ".jpeg", ".png", ".gif", ".webp"))
                                    for f in os.listdir(d)):
            n_dup += 1
            write_state(STATE, sid, ok, n_imgs, n_bytes)
            continue
        imgs = img_of(ph)
        if not imgs:
            fails["页面里没匹配到谱图"] = fails.get("页面里没匹配到谱图", 0) + 1
            write_state(STATE, sid, ok, n_imgs, n_bytes)
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        for j, iu in enumerate(dict.fromkeys(imgs)):
            full = iu if iu.startswith("http") else "http:" + iu
            data = fetch(full, binary=True, timeout=30)
            if data is None:
                fails["图片下载失败: HTTPError"] = fails.get("图片下载失败: HTTPError", 0) + 1
                continue
            if len(data) < 3000:
                fails["图太小(<3KB)"] = fails.get("图太小(<3KB)", 0) + 1
                continue
            ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
            gp = os.path.join(d, "%03d%s" % (n + 1, ext))
            part = gp + ".part"              # 原子写: 被杀最多留 .part, 不会被当成品
            with open(part, "wb") as g:
                g.write(data)
            os.replace(part, gp)
            n += 1
            n_bytes += len(data)
        if n:
            ok += 1
            n_imgs += n
            n_new += 1
            n_big += 1 if n > 1 else 0
            if n_new % 10 == 0 or n_new <= 3:
                say("  + %s (id=%d, %d 张) 新下 %d 首, 跳过 %d, 404 %d"
                    % (title[:36], sid, n, n_new, n_dup, n404))
        else:
            fails["一首图都没下到"] = fails.get("一首图都没下到", 0) + 1
        write_state(STATE, sid, ok, n_imgs, n_bytes)

    el = time.time() - t0
    say("结束(%s): 处理 %d 个 id -> 新下 %d 首 / %d 张 / %.1f MiB; 跳过(语料或已有) %d; 404 %d"
        % (stop_reason or "走完 id 段", k if ids else 0, n_new, n_imgs,
           n_bytes / 1048576.0, n_dup, n404))
    if n_new:
        say("吞吐: %.2f 首/分钟, %.2f MiB/分钟, %.1f KB/首 (用时 %.0f 分)"
            % (n_new / (el / 60.0), n_bytes / 1048576.0 / (el / 60.0),
               n_bytes / 1024.0 / n_new, el / 60.0))
    if skipped is not None:
        say(skipped.summary())
    for kk, vv in sorted(fails.items(), key=lambda kv: -kv[1]):
        say("  失败/空手 %-28s %d" % (kk, vv))
    okf, freef, msgf = check(OUT_ROOT)
    say("磁盘: " + msgf + " (本轮变化 %+.2f GiB)" % (freef - free0))
    log.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
