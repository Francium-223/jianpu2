# -*- coding: utf-8 -*-
"""按曲名在 qupu123 的"通俗唱法"分类目录里扫 -> 命中才下载。

为什么必须扫目录(2026-09-22 实测出的第三个坑):
  * qupu123 的**站内搜索搜不全**: 《黑色柳丁》明明在库里
    (https://www.qupu123.com/tongsu/sizi/heseliuding.html), 但 /Search?keys=黑色柳丁 返回 0 条。
  * 原因之一是曲谱页有**两种网址形态**: `/tongsu/<类>/p<数字>.html` 与 `/tongsu/<类>/<拼音>.html`;
    旧爬虫只认前者, 于是首轮把 5 首有页面的歌当成"网站没有"。
  * 目录页 /tongsu/<类>/<页>.html 每页 45 条**带曲名**, 且两种形态的链接都在里面
    (实测四字歌名 4597 条 / 184 页), 所以"扫目录 + 按曲名匹配 + 只下命中"既准又省。

用法: py -3.13 tools/crawl_qupu123_by_title.py <曲名1,曲名2,...> [每类最多扫几页=200]
"""
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
# **必须剥 HTML 实体**: 站点列表里的曲名带 `&nbsp;&nbsp;`, 不剥会让 `绿光&nbsp;&nbsp;` != `绿光`
ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")
PAREN = re.compile(r"[（(【\[][^)）】\]]*[)）】\]]|[（(【\[].*$")
CATS = ["sanzi", "sizi", "wuzi", "liuzi", "qizi", "bazi", "jiuziyishang"]
OUT = "images-prep/qupu123-title"
os.makedirs(OUT, exist_ok=True)

WANT = [x for x in (sys.argv[1].split(",") if len(sys.argv) > 1 else []) if x]
MAXP = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 200
if not WANT:
    sys.exit(__doc__)


def norm(s):
    s = ENT.sub("", s)
    s = re.sub(r"\[[^\]]*\]", "", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[0-9０-９]+$", "", s)
    return DROP.sub("", s.translate(ZW)).casefold()


WANTN = {w: norm(w) for w in WANT}


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "https://www.qupu123.com/"})
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


def sid_of(path):
    """p<数字>.html -> 数字; 拼音别名页 -> 拼音词(id 允许是别名, 见 to_jianpu_db.py)。"""
    m = re.search(r"/p(\d+)\.html$", path)
    if m:
        return m.group(1)
    return os.path.basename(path)[:-5]


def matched(title_norm, want, want_norm):
    """短标题(<=3 字)必须**精确相等**才认 —— 否则《红豆》会命中《红豆杉》《红豆情》,
    《大海》会命中《大海啊故乡》(2026-09-22 实测), 白下载一堆无关谱还污染语料。
    长标题允许"包含"(站点的曲名常带"演唱/词曲"等后缀)。"""
    if want_norm == title_norm:
        return True
    if len(want_norm) <= 3:
        return False
    return want_norm in title_norm


print(f"目标 {len(WANT)} 首 -> 扫 {len(CATS)} 个通俗分类\n", flush=True)
found = {}
log = io.open("train-work/qupu123_title_scan.tsv", "a", encoding="utf-8")
for cat in CATS:
    t0 = time.time()
    empty = 0
    p = 1
    while p <= MAXP:
        u = f"https://www.qupu123.com/tongsu/{cat}/" + ("" if p == 1 else f"{p}.html")
        h = None
        for _try in range(5):                     # 单页失败要重试, **不能 break 掉整个分类**
            try:                                  # (旧版一次抖动就让 sizi 只扫了 13/184 页)
                h = get(u)
                break
            except Exception:
                # qupu123 会限流: 实测连续失败多发生在第 80-90 页附近。
                # 退避要够长(1.5→3→6→12→24 秒), 否则会把"限流"误判成"扫完了"而提前收尾。
                time.sleep(1.5 * (2 ** _try))
        if h is None:
            empty += 1
            if empty >= 6:                        # 连续 6 页失败(含退避)才认输
                print(f"  [{cat}] 第 {p} 页连续失败(疑限流), 冷却 30s 后停止本类", flush=True)
                time.sleep(30)
                break
            p += 1
            continue
        items = re.findall(r'href="(/tongsu/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html)"[^>]*>([^<]{2,90})<', h)
        if not items:
            empty += 1
            if empty >= 6:
                break
            p += 1
            time.sleep(1.0)          # 空页也给点间隔, 避免被限流
            continue
        empty = 0
        for path, title in items:
            tn = norm(title)
            for w, wn in WANTN.items():
                if wn and matched(tn, w, wn) and path not in {x[0] for x in found.get(w, [])}:
                    found.setdefault(w, []).append((path, title.strip()))
                    print(f"   命中 {w} <- {title.strip()[:40]}  {path}", flush=True)
                    log.write(f"{w}\t{title.strip()}\t{path}\t{cat}\tp{p}\n")
                    log.flush()
        if p % 40 == 0:
            print(f"  [{cat}] 第 {p} 页 ({time.time()-t0:.0f}s) 累计命中 "
                  f"{sum(len(v) for v in found.values())}", flush=True)
        p += 1
        time.sleep(0.15)
    print(f"  [{cat}] 扫完 {p-1} 页, {time.time()-t0:.0f}s", flush=True)

print(f"\n命中 {sum(len(v) for v in found.values())} 个谱页, 开始下载")
ok = 0
for w, lst in found.items():
    for path, title in lst:
        sid = sid_of(path)
        d = os.path.join(OUT, f"{safe(title)}__qupu123-{sid}")
        if os.path.isdir(d) and os.listdir(d):
            ok += 1
            continue
        try:
            ph = get("https://www.qupu123.com" + path)
        except Exception:
            continue
        imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
        imgs = [urllib.parse.urljoin("https://www.qupu123.com/", x) for x in dict.fromkeys(imgs)]
        imgs = [x for x in imgs if "/Public/Uploads/" in x or "/data2/uploads/" in x]
        if not imgs:
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        for iu in imgs[:6]:
            try:
                data = get(iu, binary=True)
            except Exception:
                continue
            if len(data) < 8000:
                continue
            try:
                from PIL import Image as _I
                import io as _io
                if min(_I.open(_io.BytesIO(data)).size) < 400:
                    continue
            except Exception:
                pass
            ext = ".png" if data[:4] == b"\x89PNG" else ".jpg"
            with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
                g.write(data)
            n += 1
            time.sleep(0.15)
        if n:
            ok += 1
            print(f"   + {w} <- {title[:40]} ({n} 张)  id={sid}", flush=True)
        time.sleep(0.2)

print(f"\n完成: 下载 {ok} 个谱页 -> {OUT}")
for w in WANT:
    print(f"   {w:<16} {'命中 ' + str(len(found.get(w, []))) + ' 个谱页' if w in found else '未命中'}")
