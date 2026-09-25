# -*- coding: utf-8 -*-
"""按曲名在 jianpu.cn 的分类目录里"扫目录 -> 只下命中的那几张"。

为什么这么做: jianpu.cn 没有可用的关键词搜索(/search 是空壳), 但曲谱按**曲名字数**分类
(erzigepu=二字... qizigepu=七字), 目录里带曲名。所以按目标曲名的字数挑对应分类, 逐页扫目录,
命中才去下载, 避免把几万张全拖下来。

实测规模(2026-09-22): 四字歌谱 ~1260 页 x 30 条; 分页 URL = /<cat>/<页>.htm (页号越大越新,
基址 /<cat> 即最新一页)。

用法:
  py -3.13 tools/crawl_jianpucn_by_title.py <曲名1,曲名2,...> [每个分类最多扫几页=1400]
"""
import io
import os
import re
import sys
import time
import urllib.request

# 2026-09-25 修: 这里原来硬编码着作者 Windows 机器的 `os.chdir(r"D:\Documents_D\jianpu2")`,
# 在 Linux 上**直接 FileNotFoundError 崩掉** —— 而这个工具不在 check_tools.sh 的冒烟清单里,
# 所以烂了没人发现。现在按 `__file__` 定位, 与别的工具同一口径。
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # jianpu2/
WS = os.path.dirname(ROOT)                        # 工作区
sys.path.insert(0, HERE)
import tlsfetch                                   # noqa: E402  取页 + 证书过期兜底

# `--help` 保护: 本文件是**模块级脚本**, 没有 argparse —— 不拦的话 `--help` 会被当成
# "要爬的曲名", 真的开始扫几万页目录。(同 2026-09-24 给另外三个爬虫加的那道保护。)
if any(a in ("-h", "--help") for a in sys.argv[1:]):
    print(__doc__)
    raise SystemExit(0)

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")
ENT = re.compile(r"&[a-zA-Z]{2,8};|&#\d+;")          # `绿光&nbsp;&nbsp;` -> `绿光`
PAREN = re.compile(r"[（(【\[][^)）】\]]*[)）】\]]|[（(【\[].*$")   # `红茶馆(粤语)` -> `红茶馆`
CATS = ["erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang"]
# 图库统一落工作区 `images-prep/`(JIANPU_IMAGES 可覆盖), 不再写相对路径靠 cwd 对上
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or os.path.join(WS, "images-prep")
OUT = os.path.join(IMG_ROOT, "jianpucn-title")
SCANLOG = os.path.join(ROOT, "train-work", "jianpucn_title_scan.tsv")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.dirname(SCANLOG), exist_ok=True)

WANT = [x for x in (sys.argv[1].split(",") if len(sys.argv) > 1 else []) if x]
MAXP = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 1400


def norm(s):
    s = ENT.sub("", s)
    s = re.sub(r"\[[^\]]*\]", "", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[0-9０-９]+$", "", s)
    return DROP.sub("", s.translate(ZW)).casefold()


WANTN = {w: norm(w) for w in WANT}
if not WANT:
    sys.exit(__doc__)


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "http://www.jianpu.cn/"})
    with tlsfetch.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", "replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", re.sub(r"\[[^\]]*\]", "", s)).strip()[:60] or "untitled"


def matched(title_norm, want_norm):
    """短标题(<=3 字)必须精确相等 —— 否则《红豆》会命中《红豆杉》《红豆情》这类无关谱。"""
    if want_norm == title_norm:
        return True
    if len(want_norm) <= 3:
        return False
    return want_norm in title_norm


# 只扫需要的分类(按目标曲名字数)
need_cat = set()
for w in WANT:
    ln = len(re.findall(r"[\u4e00-\u9fff]", w))
    need_cat.add({2: "erzigepu", 3: "sanzigepu", 4: "sizigepu", 5: "wuzigepu", 6: "liuzigepu",
                  7: "qizigepu", 8: "bazigepu", 9: "jiuzigepu"}.get(ln, "shizijiyishang"))
print(f"目标 {len(WANT)} 首 -> 需扫分类 {sorted(need_cat)}\n", flush=True)

found = {}          # 曲名 -> [(url, title)]
log = io.open(SCANLOG, "a", encoding="utf-8")
for cat in CATS:
    if cat not in need_cat:
        continue
    t0 = time.time()
    for p in range(1, MAXP + 1):
        u = f"http://www.jianpu.cn/{cat}" + ("" if p == 1 else f"/{p}.htm")
        try:
            h = get(u)
        except Exception:
            break
        items = re.findall(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{1,70})<", h)
        if not items:
            break
        for path, title in items:
            tn = norm(title)
            for w, wn in WANTN.items():
                if wn and matched(tn, wn) and path not in {x[0] for x in found.get(w, [])}:
                    found.setdefault(w, []).append((path, title.strip()))
                    print(f"   命中 {w} <- {title.strip()[:44]}  {path}", flush=True)
                    log.write(f"{w}\t{title.strip()}\t{path}\t{cat}\tp{p}\n")
                    log.flush()
        if p % 100 == 0:
            print(f"  [{cat}] 第 {p} 页 ({time.time()-t0:.0f}s) 累计命中 "
                  f"{sum(len(v) for v in found.values())}", flush=True)
        time.sleep(0.15)
    print(f"  [{cat}] 扫完 {p} 页, 用时 {time.time()-t0:.0f}s", flush=True)

print(f"\n命中 {sum(len(v) for v in found.values())} 个谱页, 开始下载")
ok = 0
for w, lst in found.items():
    for path, title in lst:
        sid = re.search(r"/(\d+)\.htm", path).group(1)
        d = os.path.join(OUT, f"{safe(title)}__jianpucn-{sid}")
        if os.path.isdir(d) and os.listdir(d):
            ok += 1
            continue
        try:
            ph = get("http://www.jianpu.cn" + path)
        except Exception:
            continue
        imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]",
                                      ph, re.I) if "logo" not in x.lower()]
        if not imgs:
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        for iu in imgs[:3]:
            try:
                req = urllib.request.Request("http://www.jianpu.cn" + iu,
                                             headers={"User-Agent": UA})
                with tlsfetch.urlopen(req, timeout=25) as r, \
                        open(os.path.join(d, f"00{n+1}.jpg"), "wb") as g:
                    g.write(r.read())
                n += 1
            except Exception:
                pass
            time.sleep(0.15)
        if n:
            ok += 1
            print(f"   + {w} <- {title[:44]} ({n} 张)", flush=True)
        time.sleep(0.2)

print(f"\n完成: 下载 {ok} 个谱页 -> {OUT}")
for w in WANT:
    print(f"   {w:<16} {'命中 ' + str(len(found.get(w, []))) + ' 个谱页' if w in found else '未命中'}")
