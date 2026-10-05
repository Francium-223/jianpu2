# -*- coding: utf-8 -*-
"""爬 **风雅颂歌谱网**(fysongs.cn) 的歌谱图 —— 先落清单, 再按清单抓详情页与整页图。

实测(2026-10-06, 全部是实测值不是推测):
  * `robots.txt`(200, 5004 字节)禁的是后台与静态目录: `/admin/ /data/ /inc/ /include/
    /includek/ /install/ /iptocity/ /images/ /skin/ /js/ /model/ /qq* /user_* /shopcart*
    /addcart* /price* …`。本脚本只碰 `/songkulist.asp` 与 `/songku_show.asp`, **都不在禁列**;
    谱图在另一个域 `pic.3zitie.cn`(该域 `robots.txt` 返 404 ⇒ 无限制)。
  * 列表 `/songkulist.asp?page=N`(**50 条/页**): 不带 `d=` 是全站 **51,104 条 / 1,023 页**;
    `d=1` 是"带和弦简谱"子集 **9,056 条 / 182 页**。⚠ 实测 `d=2 / d=3 / d=5 / d=9 / d=20 /
    d=100` **全部回落到全站口径**(页数条数一模一样), 所以别拿 `d=2..` 当分类遍历, 会白扫 N 遍。
  * 每条记录结构极规整(page=1 与 page=1022 同形, 实测):
        <a href="http://www.fysongs.com/songku_show.asp?id=52238" …><span …>归</span></a>
        <a href="/singersk.asp?id=2850" …><span …>周迅</span></a>(演唱)
        <a href="/songku_show.asp?id=52238&d=1" …><span style="…13px;">带和弦简谱</span></a>
    ⚠ 老条目(2021 年前后录入的)**没有那行类型标签**, 实测 400 条采样里 193 条有
    "可下载打印"、其余无标签 ⇒ 类型只能当**可选元数据**, 不能拿它过滤, 否则老谱全丢。
  * 详情页表头 `<h2><a …><span>周迅-归(带和弦原唱完整谱)</span></a>` = `歌手-曲名(变体)`;
    谱图是 `<img id="content0" src="https://pic.3zitie.cn/fys/songku/…/xxx.jpg">`。
    ⚠ 同一页面里还混着 `/images/emptybook.gif`(微信二维码占位)与 `/img/qr.jpg`(小程序码),
    只认 `id="contentN"` 才能**只收谱面**, 免得把 logo/二维码当谱图收进去。
  * id 是顺序数字(实测最大 52,189), 但**不是每个 id 都有内容**: 实测 `id=100` 是空页
    (无标题、无图)。"没有 contentN"必须算**失败并记账**, 不能当成功。
  * 一个详情页目前实测都是**一张整页长图**(794×1626 / 647×1078 / 640×905, 185–418KB),
    但代码按 `content0..contentN` **顺序收多张**, 将来出多页谱不用改。

用法(两步: 先落清单, 再按清单抓 —— 清单可反复追加, 抓取可随时中断续跑):
    py -3.13 tools/crawl_fysongs.py --list --pages 1-4            # 全站口径, 扫前 4 页清单
    py -3.13 tools/crawl_fysongs.py --list --d 1 --pages 1-10     # "带和弦简谱"子集
    py -3.13 tools/crawl_fysongs.py --fetch --limit 150           # 按清单抓详情+图(每请求 >=1s)
    py -3.13 tools/crawl_fysongs.py --status                      # 看清单/进度/账

落盘: `images-prep/fysongs-<d|all>/<曲名>__fysongs-<id>/001.jpg, 002.jpg …`(整页图, 每首一目录)
清单: `train-work/fysongs_manifest.tsv`   进度: `train-work/fysongs_state.json`
日志: `train-work/fysongs_fetch.log`
"""
import argparse
import html as htmlmod
import json
import os
import re
import sys
import time
import urllib.request

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from jp_root import images_root                    # noqa: E402  图库根目录唯一口径

BASE = "http://www.fysongs.cn"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
SITE = "fysongs"                                   # 站点 token(目录名/语料 source 都用它)
PER_PAGE = 50                                      # 实测: 列表固定 50 条/页

MANIFEST = os.path.join(ROOT, "train-work", "fysongs_manifest.tsv")
STATE = os.path.join(ROOT, "train-work", "fysongs_state.json")
LOG = os.path.join(ROOT, "train-work", "fysongs_fetch.log")

# 只有这两个路径会请求站点(都在 robots 允许之列); 其余一律不碰。
DETAIL_URL = BASE + "/songku_show.asp?id=%s"


# ---------------------------------------------------------------- 礼貌限速
_last_req = [0.0]


def throttle(sleep):
    """"**两次请求之间**至少隔 sleep 秒(全脚本唯一出口, 列表/详情/图都走它)。"""
    dt = time.time() - _last_req[0]
    if dt < sleep:
        time.sleep(sleep - dt)
    _last_req[0] = time.time()


def fetch(url, sleep, binary=False, referer=BASE + "/", tries=3, timeout=40):
    """取一个 URL, 失败重试到 tries 次(默认 3 = 首次 + 2 次重试), 全败返回 None。"""
    last = ""
    for k in range(tries):
        throttle(sleep)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": referer})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                raw = r.read()
            if binary:
                return raw
            return raw.decode("utf-8", "replace")     # 实测页面声明 charset=utf-8
        except Exception as e:                        # noqa: BLE001  网络异常种类太多, 一律重试
            last = "%s: %s" % (type(e).__name__, e)
            if k + 1 < tries:
                time.sleep(sleep * (k + 1))
    sys.stderr.write("   ! 取不到(%d 次): %s  %s\n" % (tries, last, url))
    return None


def safe(name):
    """目录名清洗 —— 与既有爬虫同口径(去非法字符 + 限长)。"""
    name = htmlmod.unescape(name or "")
    name = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", name)
    name = re.sub(r"\s+", " ", name).strip()
    return re.sub(r"_{2,}", "_", name)[:60] or "untitled"


def safe_dir(name):
    """比 `safe()` 再稳一点: 末尾的点/空格在 Windows 上会让目录名诡异。"""
    return safe(name).strip(" .") or "untitled"


# ---------------------------------------------------------------- 解析
# 实测记录块: 标题在 songku_show.asp?id=N 的锚里, 歌手在 singersk.asp?id=N 的锚里, 类型在
# `font-size:13px;` 的灰字 span 里。三者都不跨记录 —— 一条记录 = 一个 `width:90%` 的 div。
REC_SPLIT = re.compile(r'<div style="margin: 0px auto;width:90%')
REC_TITLE = re.compile(r'href="https?://(?:www\.)?fysongs\.com/songku_show\.asp\?id=(\d+)"[^>]*>\s*'
                       r'<span[^>]*>([^<]{0,80})</span>', re.I)
REC_SINGER = re.compile(r'href="/singersk\.asp\?id=(\d+)"[^>]*>\s*<span[^>]*>([^<]{0,40})</span>', re.I)
REC_KIND = re.compile(r'font-size:13px;"\s*>([^<]{1,20})</span>')
# 类型标签必须落在**本条记录**的尾部(收藏/返回那几栏之后), 否则会串到下一条去。
REC_KIND_TAIL = re.compile(r'float:right;width:13%(.{0,600}?)</div>\s*<div style=\'float:right;width:20%',
                           re.S)
DETAIL_H2 = re.compile(r"<h2>\s*<a[^>]*>\s*<span[^>]*>([^<]*)</span>", re.I)
DETAIL_TITLE = re.compile(r"<title>([^<]*)</title>", re.I)
DETAIL_IMG = re.compile(r"<img[^>]*\bid=[\"']content(\d+)[\"'][^>]*>", re.I)
IMG_SRC = re.compile(r"src=[\"']([^\"']+)[\"']", re.I)
IMG_HOST_FALLBACK = re.compile(r"<img[^>]+src=[\"']([^\"']*pic\.3zitie\.cn/[^\"']+)[\"']", re.I)


def parse_list(html):
    """列表页 -> [(id, 曲名, 歌手, 类型)]。抽不到的字段留空字符串, **不编**。"""
    out = []
    for blk in REC_SPLIT.split(html)[1:]:
        m = REC_TITLE.search(blk)
        if not m:
            continue
        sid, title = m.group(1), htmlmod.unescape(m.group(2)).strip()
        s = REC_SINGER.search(blk)
        singer = htmlmod.unescape(s.group(2)).strip() if s else ""
        k = REC_KIND_TAIL.search(blk)
        kind = ""
        if k:
            kk = REC_KIND.search(k.group(1))
            kind = kk.group(1).strip() if kk else ""
        out.append((sid, title, singer, kind))
    return out


def parse_detail(html):
    """详情页 -> (曲名, 歌手, 类型, [图 url])。

    表头实测形如 `周迅-归(带和弦原唱完整谱)` = `歌手-曲名(变体)`; 表头取不到时退到 `<title>`
    的 `歌手【曲名】(变体)歌曲曲谱…`。两条都取不到就**留空**, 让上层用清单里的列表页标题兜底,
    绝不猜。
    """
    title = singer = kind = ""
    raw = ""
    hd = DETAIL_H2.search(html)
    if hd:
        raw = htmlmod.unescape(hd.group(1)).strip()
    if raw:
        k = re.search(r"[（(]([^）)]*)[）)]\s*$", raw)
        if k:
            kind = k.group(1).strip()
            raw = raw[:k.start()].strip()
        if "-" in raw:
            singer, title = raw.split("-", 1)
            singer, title = singer.strip(), title.strip()
        else:
            title = raw
    else:
        t = DETAIL_TITLE.search(html)
        raw = htmlmod.unescape(t.group(1)).strip() if t else ""
        m = re.match(r"(.+?)【(.+?)】(.*)", raw)
        if m:
            singer, title = m.group(1).strip(), m.group(2).strip()
            k = re.search(r"[（(]([^）)]*)[）)]", m.group(3))
            kind = k.group(1).strip() if k else ""

    # 谱图: 只认 id="contentN"(按 N 排序), 页面里别的 img 是二维码/logo, 一律不要。
    tagged = []
    for m in DETAIL_IMG.finditer(html):
        s = IMG_SRC.search(m.group(0))
        if s:
            tagged.append((int(m.group(1)), s.group(1)))
    imgs, seen = [], set()
    for n, u in sorted(tagged):
        if n in seen:
            continue
        seen.add(n)
        imgs.append(u)
    if not imgs:                       # 兜底: 万一站点去掉 id, 按图床域名认, 仍然排除 logo/二维码
        imgs = list(dict.fromkeys(IMG_HOST_FALLBACK.findall(html)))
    return title, singer, kind, imgs


def clean_img_url(u):
    if u.startswith("//"):
        return "https:" + u
    return u


# ---------------------------------------------------------------- 账
def load_state():
    try:
        with open(STATE, encoding="utf-8") as f:
            st = json.load(f)
    except Exception:
        st = {}
    for k in ("done", "fail", "skipped"):
        st.setdefault(k, {})
    return st


def save_state(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=1)
    os.replace(tmp, STATE)


def log_line(parts):
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write("\t".join(str(x) for x in parts) + "\n")


def load_manifest():
    """读清单 -> [(sid, 曲名, 歌手, 类型, 来源)]。按 id 去重保序(清单是追加写的)。"""
    rows, seen = [], set()
    if not os.path.exists(MANIFEST):
        return rows
    with open(MANIFEST, encoding="utf-8") as f:
        for ln in f:
            c = ln.rstrip("\n").split("\t")
            if len(c) < 5 or not c[0].isdigit() or c[0] in seen:
                continue
            seen.add(c[0])
            rows.append((c[0], c[1], c[2], c[3], c[4]))
    return rows


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`(爬虫侧避抓的唯一口径)。

    导入失败也照常抓 —— 宁可多下, 别因为索引坏了整轮空转。
    """
    try:
        import corpus_index
        return corpus_index
    except Exception as e:                            # noqa: BLE001
        print("  [语料索引不可用, 按老办法抓] %s: %s" % (type(e).__name__, e), flush=True)
        return None


def find_dir(out, sid):
    """按 id 找已有目录(不靠标题 —— 标题口径变了也不该重复下)。"""
    suf = "__%s-%s" % (SITE, sid)
    try:
        for e in os.listdir(out):
            if e.endswith(suf) and os.path.isdir(os.path.join(out, e)):
                return os.path.join(out, e)
    except OSError:
        pass
    return None


def dir_has_images(d):
    try:
        return any(re.search(r"\.(jpg|jpeg|png|gif)$", x, re.I) and os.path.getsize(os.path.join(d, x)) > 0
                   for x in os.listdir(d))
    except OSError:
        return False


def ext_of(data):
    if data[:4] == b"\x89PNG":
        return ".png"
    if data[:3] == b"GIF":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


# ---------------------------------------------------------------- 子命令
def parse_pages(spec):
    """`1-4` / `7` / `1,3,5` -> 页号列表(升序去重)。"""
    out = []
    for part in str(spec).split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return sorted(set(p for p in out if p >= 1))


def cmd_list(a):
    """--list: 按 d=/页范围扫列表, 追加进"待抓清单"。清单是**追加**的, 重复扫不会重复记。"""
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    already = {r[0] for r in load_manifest()}
    pages = parse_pages(a.pages)
    got, new, t0 = 0, 0, time.time()
    fh = open(MANIFEST, "a", encoding="utf-8")
    try:
        for p in pages:
            url = BASE + "/songkulist.asp?page=%d" % p + (("&d=%s" % a.d) if a.d else "")
            h = fetch(url, a.sleep)
            if h is None:
                print("  列表页取不到, 跳过: page=%d" % p, flush=True)
                continue
            recs = parse_list(h)
            got += len(recs)
            # 站点每页显示"共 N 页 共 M 件", 落一行到屏幕上, 便于对照清单规模
            tot = re.search(r"共\s*<b>\s*(\d+)\s*</b>\s*页", h)
            cnt = re.search(r"共&nbsp;<b>\s*(\d+)\s*</b>", h)
            for sid, title, singer, kind in recs:
                if sid in already:
                    continue
                already.add(sid)
                fh.write("\t".join([sid, title, singer, kind, "d=%s p=%d" % (a.d or "all", p)]) + "\n")
                new += 1
                if a.limit and new >= a.limit:
                    break
            fh.flush()
            print("  page %-5d 本页 %d 条, 新增 %d, 累计清单 %d  %s"
                  % (p, len(recs), new, len(already),
                     ("(站点称共 %s 页 / %s 件)" % (tot.group(1), cnt.group(1))) if tot and cnt else ""),
                  flush=True)
            if a.limit and new >= a.limit:
                print("  达到 --limit %d, 停" % a.limit, flush=True)
                break
    finally:
        fh.close()
    print("\n清单: %s(本次扫 %d 页 / 见 %d 条 / 新增 %d 条 / 清单共 %d 条), 用时 %.0fs"
          % (MANIFEST, len(pages), got, new, len(already), time.time() - t0), flush=True)


def cmd_fetch(a):
    """--fetch: 按清单抓详情页 + 整页图。限速、失败重试、断点续爬、写日志、语料避抓。"""
    rows = load_manifest()
    if not rows:
        print("清单是空的(%s) —— 先跑 --list" % MANIFEST)
        return 1
    out = a.out or os.path.join(images_root(), "fysongs-%s" % (a.d or "all"))
    os.makedirs(out, exist_ok=True)
    st = load_state()
    ci = _corpus_index()
    counter = ci.SkipCounter() if ci is not None else None

    t0 = time.time()
    songs = imgs_n = bytes_n = pages_per_song = resumed = 0
    fails = {}
    try:
        for i, (sid, ltitle, lsinger, lkind, src) in enumerate(rows, 1):
            if a.limit and songs >= a.limit:
                break
            if sid in st["done"]:
                resumed += 1
                # 状态里的谱种标签按**列表页优先**的口径刷新一下: 早先的记录用的是"详情页表头括号里
                # 那句说明"(完整版/粤语…), 不是谱种。清单里有标签就以清单为准(清单是权威)。
                if lkind and st["done"][sid].get("kind") != lkind:
                    st["done"][sid]["kind"] = lkind
                continue
            # ① 语料避抓(按站内 id + 列表页曲名) —— 命中就**连详情页都不请求**
            if ci is not None:
                r = ci.skip_reason(SITE, sid, ltitle)
                if r:
                    if counter:
                        counter.count(r)
                        if r == "title":
                            counter.note_title_skip(ltitle[:40])
                    st["skipped"][sid] = r
                    log_line([time.strftime("%F %T"), sid, "skip-" + r, ltitle, lsinger, 0, 0, ""])
                    continue
            # ② 断点续爬: 目录在且图非空 -> 记账跳过(图目录按 id 认, 不看标题)
            d = find_dir(out, sid)
            if d and dir_has_images(d):
                n = len([x for x in os.listdir(d) if re.search(r"\.(jpg|jpeg|png|gif|webp)$", x, re.I)])
                sz = sum(os.path.getsize(os.path.join(d, x)) for x in os.listdir(d)
                         if re.search(r"\.(jpg|jpeg|png|gif|webp)$", x, re.I))
                st["done"][sid] = {"title": ltitle, "singer": lsinger, "kind": lkind, "imgs": n,
                                   "bytes": sz, "at": time.strftime("%F %T"), "dir": os.path.basename(d)}
                resumed += 1
                songs += 1
                imgs_n += n
                bytes_n += sz
                pages_per_song += n
                continue

            # ③ 详情页(失败重试 2 次后记账跳过)
            dh = fetch(DETAIL_URL % sid, a.sleep, referer=BASE + "/")
            if dh is None:
                fails["详情页取不到"] = fails.get("详情页取不到", 0) + 1
                st["fail"][sid] = {"err": "detail-fetch", "n": st["fail"].get(sid, {}).get("n", 0) + 1,
                                   "at": time.strftime("%F %T"), "title": ltitle}
                log_line([time.strftime("%F %T"), sid, "fail-detail", ltitle, lsinger, 0, 0, ""])
                continue
            dtitle, dsinger, dkind, urls = parse_detail(dh)
            title = dtitle or ltitle          # 抽不到就如实用列表页标题, 不编
            singer = dsinger or lsinger
            # 谱种标签(实测): 列表页那行灰字才是**谱种**(可下载打印 / 带和弦简谱), 详情页表头括号里
            # 往往是**变体说明**(完整版 / 粤语 / 童声) —— 所以列表页优先, 只有列表页没标签
            # 的老条目才退到详情页那句说明。
            kind = lkind or dkind
            if not urls:
                fails["详情页无 contentN 谱图"] = fails.get("详情页无 contentN 谱图", 0) + 1
                st["fail"][sid] = {"err": "no-image", "n": st["fail"].get(sid, {}).get("n", 0) + 1,
                                   "at": time.strftime("%F %T"), "title": title}
                log_line([time.strftime("%F %T"), sid, "fail-noimg", title, singer, 0, 0, ""])
                print("   ✗ %s 详情页没有谱图(id=%s)" % (title[:30], sid), flush=True)
                continue
            # ④ 拿到**真曲名**后再判一次语料(列表页标题有时带变体后缀, 归一化后才对得上)
            if ci is not None and title != ltitle:
                r2 = ci.skip_reason(SITE, "", title)
                if r2:
                    if counter:
                        counter.count(r2)
                        counter.note_title_skip(title[:40])
                    st["skipped"][sid] = r2
                    log_line([time.strftime("%F %T"), sid, "skip-" + r2, title, singer, 0, 0, ""])
                    continue

            # ⑤ 下载整页图
            d = os.path.join(out, "%s__%s-%s" % (safe_dir(title), SITE, sid))
            os.makedirs(d, exist_ok=True)
            n = sz = 0
            for k, u in enumerate(urls, 1):
                data = fetch(clean_img_url(u), a.sleep, binary=True,
                             referer=DETAIL_URL % sid, tries=3)
                if not data or len(data) < 1024:      # 实测谱图 185–418KB; <1KB 必然是错误页
                    continue
                gp = os.path.join(d, "%03d%s" % (k, ext_of(data)))
                # 原子落盘(.part -> replace): 看门狗的硬止损闸是**直接杀进程**的, 直接写目标名的话,
                # 杀在写一半时会在图目录里留一张截断的 jpg —— 续爬时 `dir_has_images` 只按"有图且
                # 大小>0"判, 会把半张图当成品收下且永不重下。先写 .part(不匹配图片后缀, 续爬不认),
                # 写完再 rename, 于是被杀时最多留一个 .part, 下次照常重抓。
                part = gp + ".part"
                with open(part, "wb") as g:
                    g.write(data)
                os.replace(part, gp)
                n += 1
                sz += len(data)
            if not n:
                fails["谱图一张都没下下来"] = fails.get("谱图一张都没下下来", 0) + 1
                st["fail"][sid] = {"err": "img-fetch", "n": st["fail"].get(sid, {}).get("n", 0) + 1,
                                   "at": time.strftime("%F %T"), "title": title}
                log_line([time.strftime("%F %T"), sid, "fail-img", title, singer, 0, 0, ""])
                try:
                    os.rmdir(d)
                except OSError:
                    pass
                continue

            songs += 1
            imgs_n += n
            bytes_n += sz
            pages_per_song += n
            st["done"][sid] = {"title": title, "singer": singer, "kind": kind, "imgs": n,
                               "bytes": sz, "at": time.strftime("%F %T"), "dir": os.path.basename(d)}
            log_line([time.strftime("%F %T"), sid, "ok", title, singer, n, sz, os.path.basename(d)])
            print("   + [%d] %s%s  %d 页 / %.0fKB" % (songs, title[:34],
                                                     ("（%s）" % singer[:12]) if singer else "",
                                                     n, sz / 1024.0), flush=True)
            if songs % 10 == 0:
                save_state(st)
    except KeyboardInterrupt:
        print("\n  收到中断, 已保存进度, 下次接着跑", flush=True)
    finally:
        save_state(st)

    dt = time.time() - t0
    print("\n===== 本轮实测 =====")
    print("抓成 %d 首 / 图 %d 张 / 平均每首 %.2f 页 / 总体积 %.1f MB"
          % (songs, imgs_n, (pages_per_song / songs) if songs else 0.0, bytes_n / 1048576.0))
    print("耗时 %.0fs(%.2f 首/分钟)%s" % (dt, (songs / dt * 60) if dt else 0,
                                        ("  其中续爬跳过 %d 首" % resumed) if resumed else ""))
    if counter is not None:
        print(counter.summary())
    if fails:
        print("失败 %d 首:" % sum(fails.values()))
        for k, v in sorted(fails.items(), key=lambda kv: -kv[1]):
            print("   %-26s %d" % (k, v))
    else:
        print("失败 0 首")
    print("日志: %s" % LOG)
    return 0


def cmd_status(a):
    rows = load_manifest()
    st = load_state()
    print("清单 %s: %d 条" % (MANIFEST, len(rows)))
    print("进度 %s: 抓成 %d / 失败 %d / 语料跳过 %d"
          % (STATE, len(st["done"]), len(st["fail"]), len(st["skipped"])))
    if rows and os.path.exists(LOG):
        ok = sum(1 for _ in open(LOG, encoding="utf-8") if "\tok\t" in _)
        print("日志 %s: ok 行 %d" % (LOG, ok))
    return 0


def cmd_selftest(a):
    """--selftest: 拿**真实页面截下来的片段**验解析器(不联网), 免得结构一变静默收 0 条。"""
    lst = ('<div style="margin: 0px auto;width:90%">'
           '<a href="http://www.fysongs.com/songku_show.asp?id=52238" target=_blank> '
           '<span  style="font-size:15px;font-weight:400;">归</span></a>'
           '<div style=\'float:left;width:15%;\'><a href="/singersk.asp?id=2850" target=_blank> '
           '<span  style="font-size:13px;font-weight:400;">周迅</span></a>(演唱)</div>'
           '<div style=\'float:right;width:13%;\'>'
           '<a href="/songku_show.asp?id=52238&d=1" target=_blank> '
           '<span  style="color:#999999;font-size:13px;" >带和弦简谱</span></a>'
           '</div><div style=\'float:right;width:20%;\'>(2949)</div></div>'
           # 第二条: 老条目, **没有**类型标签(实测 2021 年前录入的都这样)
           '<div style="margin: 0px auto;width:90%">'
           '<a href="http://www.fysongs.com/songku_show.asp?id=29256" target=_blank> '
           '<span  style="font-size:15px;font-weight:400;">打工歌</span></a>'
           '<div style=\'float:left;width:15%;\'><a href="/singersk.asp?id=5727" target=_blank> '
           '<span  style="font-size:13px;font-weight:400;">小卿</span></a>(演唱)</div>'
           '<div style=\'float:right;width:13%;\'> </div>'
           '<div style=\'float:right;width:20%;\'>(414)</div></div>')
    det = ('<h2><a href="/songku_show.asp?id=52238"  ><span style="color:#ffffff;">周迅-归'
           '(带和弦原唱完整谱)</span></a></h2>'
           '<img  id="ewmcode" src="/images/emptybook.gif">'
           '<img id="content0"  src="https://pic.3zitie.cn/fys/songku/2025/04/73/pic/imgpc/x.jpg">'
           '<img src="/img/qr.jpg">')
    got = parse_list(lst)
    exp = [("52238", "归", "周迅", "带和弦简谱"), ("29256", "打工歌", "小卿", "")]
    assert got == exp, "列表解析不符:\n  得到 %r\n  期望 %r" % (got, exp)
    dt, ds, dk, imgs = parse_detail(det)
    assert (dt, ds, dk) == ("归", "周迅", "带和弦原唱完整谱"), (dt, ds, dk)
    assert imgs == ["https://pic.3zitie.cn/fys/songku/2025/04/73/pic/imgpc/x.jpg"], imgs
    # 只有 contentN 才收: 二维码/占位图必须被排除(别的站混入过宣传图, 这是那道闸)
    assert "emptybook" not in " ".join(imgs) and "qr.jpg" not in " ".join(imgs), imgs
    print("自检通过: 列表解析 2 条(含无类型标签的老条目) / 详情解析 曲名+歌手+类型 / "
          "谱图只认 contentN(二维码与占位图已排除)")
    return 0


def main():
    ap = argparse.ArgumentParser(description="风雅颂歌谱网(fysongs.cn)歌谱爬虫")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--list", action="store_true", help="扫列表页, 落/追加待抓清单")
    g.add_argument("--fetch", action="store_true", help="按清单抓详情页与整页图")
    g.add_argument("--status", action="store_true", help="看清单规模与抓取进度")
    g.add_argument("--selftest", action="store_true", help="不联网, 用真实片段验解析器")
    ap.add_argument("--d", default="", help="分类: 留空=全站(51104 条), 1=带和弦简谱(9056 条); "
                                          "实测 2/3/5/9/20/100 都回落全站口径, 别当分类用")
    ap.add_argument("--pages", default="1-3", help="页范围(仅 --list), 如 1-4 / 1,3,5 / 7")
    ap.add_argument("--limit", type=int, default=0,
                    help="最多抓多少首(0=不限; 语料跳过的与续爬已有的都不计入这个数)")
    ap.add_argument("--sleep", type=float, default=1.2, help="两次请求间隔秒数, 下限 1.0")
    ap.add_argument("--out", default="", help="图目录(默认 images-prep/fysongs-<d|all>)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    a.sleep = max(1.0, a.sleep)                       # 纪律: 限速不低于 1 秒/请求
    if a.list:
        return cmd_list(a)
    if a.fetch:
        return cmd_fetch(a)
    if a.status:
        return cmd_status(a)
    return cmd_selftest(a)


if __name__ == "__main__":
    sys.exit(main() or 0)
