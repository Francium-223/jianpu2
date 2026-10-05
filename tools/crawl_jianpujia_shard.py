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
    """唯一网络出口 —— 每个请求**前**都过 `throttle()`(>=1 秒/请求)。

    失败一律返回 `None`, **绝不往上抛**。为什么(2026-10-06 实测踩到): 这里原来只捕
    `HTTPError`(即 4xx/5xx), 而**连接超时**抛的是 `URLError(WinError 10060)` ——
    分片 2 跑到第 7.8 分钟时遇到一次超时, 整个进程直接崩掉(退出码 1), 那一片当时已抓的
    162 首靠状态文件保住了, 但这一轮的剩余配额白扔(靠计划任务 5 分钟后再拉起)。
    抓取是长跑, 单次网络抖动不该打断整片, 所以 `URLError` / `OSError` / `TimeoutError`
    一并按"这一次没取到"处理, 由调用方记进失败统计。
    """
    throttle()
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        if log is not None:
            log.write("%d\t%d\tHTTP %s\n" % (int(time.time()), 0, e.code))
        return None
    except (urllib.error.URLError, OSError, TimeoutError) as e:
        if log is not None:
            log.write("%d\t%d\t网络 %s\n" % (int(time.time()), 0, type(e).__name__))
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
    """独立状态文件。第 1 行是计量 `last_id\tok\tn_imgs\tbytes`; 之后是**空段留档**行
    `seg\t<段号>\tempty\t<采样数>\t<命中数>\t<时间>\t<采样id逗号分隔>`。

    返回 `(last, ok, n_imgs, n_bytes, empty_segments)`; 文件损坏/缺失就当作全新(不赌)。
    老格式(只有第 1 行)照常能读 —— 空段表为空。
    """
    if not os.path.exists(p):
        return 0, 0, 0, 0, {}
    last = ok = n = nb = 0
    empty = {}
    try:
        with io.open(p, encoding="utf-8") as f:
            for i, line in enumerate(f):
                parts = line.rstrip("\n").split("\t")
                if i == 0:
                    last, ok, n, nb = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
                elif len(parts) >= 6 and parts[0] == "seg" and parts[2] == "empty":
                    empty[int(parts[1])] = {"n": int(parts[3]), "hit": int(parts[4]),
                                            "at": parts[5], "ids": parts[6] if len(parts) > 6 else ""}
    except Exception:
        return 0, 0, 0, 0, {}
    return last, ok, n, nb, empty


def write_state(p, last, ok, n, nb, empty_segments=None):
    """**原子写**(.part -> os.replace): 被硬止损直接杀进程时不留半个状态文件。

    空段留档一并落盘, 而且是**可复核、可重探**的: 每次记住"段号 / 采样数 / 命中数 / 采样时刻 /
    采样了哪些 id"。**不是**"连续 N 个 404 就永久放弃"那种不可逆规则 —— 想重探就带
    `--recheck`(见 main), 或者把状态文件里对应那行删掉。
    """
    t = p + ".part"
    with io.open(t, "w", encoding="utf-8") as g:
        g.write("%d\t%d\t%d\t%d\n" % (last, ok, n, nb))
        for seg in sorted((empty_segments or {})):
            d = empty_segments[seg]
            g.write("seg\t%d\tempty\t%d\t%d\t%s\t%s\n"
                    % (seg, d["n"], d["hit"], d["at"], d.get("ids", "")))
    os.replace(t, p)


def seg_of(sid, segsize):
    return sid // segsize


def probe_segment(seg, segsize, start, end, nprobe, say):
    """探测一个 id 段是否**整段都没有曲谱**, 返回 `(is_empty, hits)`。

    为什么这么做(2026-10-06 实测): jianpujia 的 id 空间是**分段分配**的 ——
      * `200000–206000` 段 101 个 id **全部 404**(0% 命中);
      * `440000–446000` 段 101 个 id **全部 200**(100% 命中)。
    线性把 45 万个 id 逐个走一遍, 有一大半是纯空段, 约 26 小时的请求白扔。所以进入一个新段之前
    先均匀采样 `nprobe` 个 id: 全 404 就整段跳过(留档, 可重探); 只要有一个命中就照常逐 id 扫。

    采样用**同一份 `fetch()`**(先 `throttle()`), 所以这些请求也计入 >=1 秒/请求的节奏, 不会
    给站点加压。命中的那 8 个 id 会被上层**并入正式扫描**, 避免"采样过了又扫一遍"的浪费。
    """
    lo = max(start, seg * segsize)
    hi = min(end, (seg + 1) * segsize - 1)
    if hi < lo:
        return True, []
    span = hi - lo + 1
    step = max(1, span // max(1, nprobe))
    sids = list(range(lo, hi + 1, step))[:nprobe]
    hits = []
    for sid in sids:
        if fetch("%s/jianpu/%d.html" % (BASE, sid)) is not None:
            hits.append(sid)
    is_empty = not hits
    say("  [段 %d 探测] id %d..%d 采样 %d 个 -> 命中 %d 个 => %s"
        % (seg, lo, hi, len(sids), len(hits), "整段空, 跳过" if is_empty else "有货, 照常扫"))
    return is_empty, hits


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
    ap.add_argument("--seg", type=int, default=5000,
                    help="**空段探测**的段宽(默认 5000)。进入新段前先均匀采样 --seg-probe 个 id, "
                         "全 404 就整段跳过(留档进状态文件, 可 --recheck 重探)")
    ap.add_argument("--seg-probe", type=int, default=8, help="每段采样几个 id(默认 8)")
    ap.add_argument("--recheck", action="store_true",
                    help="**重探**: 忽略状态文件里的空段留档(旧档先备份成 .recheck-<时刻>.bak), 重新探测")
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

    last, ok, n_imgs, n_bytes, empty_segments = read_state(STATE)
    if a.recheck:
        n_old = len(empty_segments)
        empty_segments = {}
        # 重探是**可逆**的: 旧留档先另存成 .recheck-<时刻>.bak, 想回溯还在
        try:
            bak = STATE + ".recheck-%s.bak" % time.strftime("%Y%m%d_%H%M%S")
            io.open(bak, "w", encoding="utf-8").write("# recheck at %s, 清掉的空段留档 %d 条\n"
                                                     % (time.strftime("%F %T"), n_old))
            say("--recheck: 清掉 %d 条空段留档(旧档备份到 %s), 下一轮重新探测"
                % (n_old, os.path.basename(bak)))
        except Exception as e:
            say("--recheck: 备份失败但继续(%s)" % e)
    if last:
        ids = [i for i in ids if i > last]
        say("续爬: 从状态文件跳过 id <= %d, 剩 %d 个" % (last, len(ids)))

    ci = corpus()
    skipped = ci.SkipCounter() if ci is not None else None
    fails = {}
    n404 = n_dup = n_new = n_big = n_skipped_segs = 0
    stop_reason = ""
    seg_done = set()                 # 本次已"整段处理过"的段号
    seg_cursor = {}                  # 本次处理到段内哪个 id(给下一轮推进用)
    # 按段推进的重排: 段内保持原序(片 k 走 id≡k mod 3 -> 段内仍是稀疏序列)
    by_seg = {}
    for i in ids:
        by_seg.setdefault(seg_of(i, a.seg), []).append(i)
    say("共 %d 个 id 落在 %d 个段(段宽 %d); 状态里已有 %d 个空段留档"
        % (len(ids), len(by_seg), a.seg, len(empty_segments)))

    def save(sid):
        write_state(STATE, sid, ok, n_imgs, n_bytes, empty_segments)

    def scan_one(sid, ph):
        """处理一个**详情页已经取到**的 id。返回 True 表示这首算"新下"。"""
        nonlocal ok, n_imgs, n_bytes, n_dup
        title = song_title(ph, sid)
        if ci is not None:
            r = ci.skip_reason("jianpujia", str(sid), title)
            if r:
                skipped.count(r)
                if r == "title":
                    skipped.note_title_skip(title[:44])
                n_dup += 1
                return False
        d = os.path.join(OUT, "%s__jianpujia-%d" % (safe(title), sid))
        if os.path.isdir(d) and any(f.lower().endswith((".jpg", ".jpeg", ".png", ".gif", ".webp"))
                                    for f in os.listdir(d)):
            n_dup += 1
            return False
        imgs = img_of(ph)
        if not imgs:
            fails["页面里没匹配到谱图"] = fails.get("页面里没匹配到谱图", 0) + 1
            return False
        os.makedirs(d, exist_ok=True)
        n = 0
        for iu in dict.fromkeys(imgs):
            full = iu if iu.startswith("http") else "http:" + iu
            data = fetch(full, binary=True, timeout=30)
            if data is None:
                fails["图片下载失败"] = fails.get("图片下载失败", 0) + 1
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
            return True
        fails["一首图都没下到"] = fails.get("一首图都没下到", 0) + 1
        return False

    for seg in sorted(by_seg):
        if n_new >= a.quota or (a.max_min and (time.time() - t0) > a.max_min * 60):
            break
        if seg in empty_segments and not a.recheck and seg not in seg_done:
            # 留档说这整段没有曲谱 -> 跳过整段(留档可复核、可 --recheck 重探)
            n_skipped_segs += 1
            d = empty_segments[seg]
            say("  [段 %d] 跳过(留档 %s 采样 %d 个命中 %d 个)" % (seg, d["at"], d["n"], d["hit"]))
            continue

        probe_hits = []
        if seg not in seg_done:
            seg_done.add(seg)
            is_empty, probe_hits = probe_segment(seg, a.seg, a.start, a.end, a.seg_probe, say)
            if is_empty:
                empty_segments[seg] = {
                    "n": a.seg_probe, "hit": 0,
                    "at": time.strftime("%F %T"),
                    "ids": ",".join(str(seg * a.seg + j) for j in range(min(a.seg_probe, 3)))}
                n_skipped_segs += 1
                say("      -> 整段空, 已写进状态文件(可 --recheck 重探)")
                continue
            if seg in empty_segments:        # --recheck 发现"其实有货" -> 撤销旧留档
                empty_segments.pop(seg, None)
                say("      -> 段 %d 旧留档说空, 本次实测有货, 已撤销该留档" % seg)

        # 探测命中的那 8 个 id **优先处理**(复用采样结果, 不再重复请求)
        rest = [i for i in by_seg[seg] if i not in set(probe_hits)]
        for sid in list(probe_hits) + rest:
            if n_new >= a.quota:
                stop_reason = "到配额 %d" % a.quota
                break
            if a.max_min and (time.time() - t0) > a.max_min * 60:
                stop_reason = "到 --max-min"
                break
            if sid in probe_hits:
                ph = fetch("%s/jianpu/%d.html" % (BASE, sid))
                if ph is None:
                    continue
            else:
                okf, _f, msgf = check(OUT_ROOT)
                if not okf:
                    say("!! " + msgf + " -> 立即收工")
                    stop_reason = "磁盘止损"
                    break
                ph = fetch("%s/jianpu/%d.html" % (BASE, sid))
                if ph is None:
                    n404 += 1                  # 404 / 网络抖动: 这个 id 没看成
                    continue
            if scan_one(sid, ph):
                n_new += 1
                if n_new % 10 == 0 or n_new <= 3:
                    say("  + id=%d 新下 %d 首, 跳过 %d, 404 %d" % (sid, n_new, n_dup, n404))
            save(sid)
        if stop_reason:
            break
    if not stop_reason:
        stop_reason = "走完 id 段"

    el = time.time() - t0
    say("结束(%s): 本片候选 %d 个 id -> 新下 %d 首 / %d 张 / %.1f MiB; 跳过(语料或已有) %d; 未取到 %d"
        % (stop_reason or "走完 id 段", len(ids), n_new, n_imgs,
           n_bytes / 1048576.0, n_dup, n404))
    say("空段: 本次跳过 %d 个段(段宽 %d), 状态文件里留档 %d 条(可 --recheck 重探)"
        % (n_skipped_segs, a.seg, len(empty_segments)))
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
