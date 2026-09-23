# -*- coding: utf-8 -*-
"""按"歌手索引页"定向补谱(jianpujia) —— 站内搜索已被关闭, 只能翻歌手页再按曲名匹配。

为什么必须这样做(2026-09-22 实测):
  * jianpujia 的 /e/search/index.php 对**任何**关键词都返回"没有搜索到相关的内容"
    (连《菊花台》都搜不到) -> 搜索功能实际被关掉, 不能用。
  * 但 /sitemap.html 给出 85 个歌手/分类索引页 /list/<id>-<页>.html, 歌手页里带曲名,
    所以"翻页 + 按曲名匹配 + 只下命中的"是可行的定向补法。
  * 站点 SSL 证书**已过期**, 必须显式用不校验的 context(我们只读公开曲谱图)。

用法: py -3.13 tools/crawl_jianpujia_by_artist.py <歌手id> <歌手名> <曲名1,曲名2,...> [最多翻几页=60]
"""
import io
import os
import re
import ssl
import sys
import time
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()
BASE = "http://www.jianpujia.com"
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|]+")

CAT = sys.argv[1]
NAME = sys.argv[2]
WANT = [x for x in sys.argv[3].split(",") if x]
ALL = (len(WANT) == 1 and WANT[0].upper() in ("ALL", "*", "全部"))   # 整页抓全(不按曲名过滤)
PAGES = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 60
OUT = os.path.join("images-prep", f"jianpujia-art{CAT}")
os.makedirs(OUT, exist_ok=True)


def norm(s):
    return DROP.sub("", s.translate(ZW)).casefold()


WANTN = {w: norm(w) for w in WANT}


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=35, context=CTX) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


def mainl(h):
    """只取 <div class="mainl">…<!--@ mainl--> 这一段 —— 右侧 <div class="mainr"> 是每页都重复的
    推荐侧栏(实测每页都混着《回忆的阁楼》《西海情歌》等无关条目), 不切掉会把侧栏当列表,
    而且会因为"几页之间没有新链接"而**提前退出翻页**(实测只翻到第 2 页就停了)。"""
    i = h.find('class="mainl"')
    if i < 0:
        return ""
    j = h.find("<!--@ mainl-->", i)
    return h[i:j if j > i else len(h)]


items = []
last = None
for page in range(0, PAGES):
    try:
        h = fetch(f"{BASE}/list/{CAT}-{page}.html")
    except Exception:
        break
    if last is None:                      # 从分页器读总页数(尾页链接)
        nums = [int(x) for x in re.findall(r"/list/%s-(\d+)\.html" % CAT, h)]
        last = max(nums) if nums else 0
        print(f"   {NAME}: 共 {last+1} 页", flush=True)
    found = re.findall(r'href="(/jianpu/(\d+)\.html)"[^>]*>([^<]{2,90})', mainl(h))
    new = [(p, t) for p, _i, t in found if p not in {x[0] for x in items}]
    items.extend(new)
    if page >= last:
        break
    time.sleep(0.25)

print(f"{NAME}(id={CAT}): 翻到 {len(items)} 个谱页; 目标 {len(WANT)} 首", flush=True)

hit, ok = [], 0
for path, title in items:
    tn = norm(title)
    matched = WANT if ALL else [w for w, wn in WANTN.items() if wn and wn in tn]
    if not matched:
        continue
    sid = re.search(r"/(\d+)\.html", path).group(1)
    d = os.path.join(OUT, f"{safe(title)}__jianpujia-{sid}")
    if os.path.isdir(d) and os.listdir(d):
        ok += 1
        hit.append((matched[0], title, sid, "已有"))
        continue
    try:
        ph = fetch(BASE + path)
    except Exception:
        continue
    imgs = re.findall(r'<img[^>]+src="((?:https?:)?//image\.jianpujia\.com/[^"]+)"', ph, re.I)
    if not imgs:
        continue
    os.makedirs(d, exist_ok=True)
    n = 0
    for iu in dict.fromkeys(imgs):
        full = iu if iu.startswith("http") else "http:" + iu
        try:
            data = fetch(full, binary=True)
        except Exception:
            continue
        if len(data) < 3000:
            continue
        ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
        with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
            g.write(data)
        n += 1
        time.sleep(0.15)
    if n:
        ok += 1
        hit.append((matched[0], title, sid, f"{n}张"))
        print(f"   + {matched[0]} <- {title[:44]} ({n} 张)", flush=True)
    time.sleep(0.25)

print(f"\n{NAME}: 命中 {len(hit)} 个谱页, 下载成功 {ok} -> {OUT}")
for w, t, sid, st in hit:
    print(f"   {w:<14} {t[:46]:<48} {st}")
