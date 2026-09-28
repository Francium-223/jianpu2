# -*- coding: utf-8 -*-
"""爬 jp114.com(简谱库, 图床 imgs.92kk.com) 的**分类列表**, 下简谱图。

为什么值得单开一个源(2026-09-29 实测):
  * 它是**新站点**, 语料里目前只有 jianpucn(3,769 首) / jianpujia(1,207 首) / qupu123;
  * 列表页 `/jianpu/lists-<分类>-<页>.html`, 每页 25 条, 分类有 通俗流行=14 / 影视=17 /
    最新=24 / 手稿=23 / 吉他=4 …;
  * 详情页 `/jianpu/<id>.html` 里谱图是**单引号** `src='//imgs.92kk.com/attachment/jianpu/...'`
    (只按双引号找会一张都抓不到 —— 实测踩过), 一个页面可能有多张(多页谱);
  * 搜索接口 `GET /search.html?key=<词>` 也能用, 但**对 2024 新歌没有货**
    (实测 小美满/缝合/借过一下/才星期三/暮色回响/纯妹妹/瘦子 全是 0 命中), 所以榜单缺口别指望它。

用法: py -3.13 tools/crawl_jp114.py <分类id> <分类名> [最多下几首=200] [从第几页=1]
输出: images-prep/jp114-<分类id>/<曲名>__jp114-<id>/001.jpg...
"""
import os
import re
import ssl
import sys
import time
import urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl._create_unverified_context()
BASE = "https://www.jp114.com"

CAT = sys.argv[1] if len(sys.argv) > 1 else "14"
NAME = sys.argv[2] if len(sys.argv) > 2 else CAT
CAP = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 200
START = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 1
OUT = os.path.join("images-prep", f"jp114-{CAT}")
os.makedirs(OUT, exist_ok=True)


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=35, context=CTX) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


def clean_title(detail_html, fallback):
    """详情页 <title> 形如 `尽孝须趁早简谱,尽孝须趁早曲谱_流行简谱_简谱库` -> 取逗号前、去掉"简谱"。"""
    m = re.search(r"<title>([^<]*)</title>", detail_html)
    if m:
        t = m.group(1).split(",")[0].strip()
        t = re.sub(r"简谱$", "", t).strip()
        if 2 <= len(t) <= 60:
            return t
    return re.sub(r"简谱歌词$", "", fallback).strip() or fallback


# ---- 1) 收集列表 ----
# ⚠ 分页控件显示的"共 9 页"是**骗人的**(只列出一小段页码): 实测第 200 页仍有新条目。
# 所以判停不用页码上限, 而用"这一页没有新 id"(或超过 MAXPAGES 保护)。
MAXPAGES = int(os.environ.get("JP114_MAXPAGES", "400"))
items, page, seen_ids, dry_pages = [], START, set(), 0
while len(items) < CAP * 3 and page <= MAXPAGES:
    try:
        h = fetch(f"{BASE}/jianpu/lists-{CAT}-{page}.html")
    except Exception as e:
        print(f"  列表失败 {page}: {type(e).__name__}", flush=True)
        break
    found = re.findall(r'href="(/jianpu/(\d+)\.html)"[^>]*>([^<]{2,90})', h)
    fresh = 0
    for path, sid, txt in found:
        if sid in seen_ids:
            continue
        seen_ids.add(sid)
        items.append((path, sid, txt.replace("&nbsp;", " ").strip()))
        fresh += 1
    if page == START:
        print(f"   {NAME}(id={CAT}): 从第 {START} 页开始扫(分页控件显示的页数不可信)", flush=True)
    if fresh == 0:
        dry_pages += 1
        if dry_pages >= 2:                 # 连续两页没有新 id -> 到底了
            break
    else:
        dry_pages = 0
    page += 1
    if page % 25 == 0:
        print(f"   已扫到第 {page} 页, 收集 {len(items)}", flush=True)
    time.sleep(0.25)

print(f"{NAME}: 收集 {len(items)} 个谱页, 下载上限 {CAP}", flush=True)
ok = skipped = 0
for path, sid, txt in items:
    if ok >= CAP:
        break
    # 先看目录在不在(用 id 判, 免得标题清洗口径变化导致重复下载)
    d = None
    for e in os.listdir(OUT):
        if e.endswith(f"__jp114-{sid}"):
            d = os.path.join(OUT, e)
            break
    if d and os.listdir(d) and any(f.lower().endswith((".jpg", ".jpeg", ".png")) for f in os.listdir(d)):
        skipped += 1
        ok += 1
        continue
    try:
        ph = fetch(BASE + path)
    except Exception:
        continue
    imgs = re.findall(r"<img[^>]+src=['\"](//imgs\.92kk\.com/[^'\"]+)['\"]", ph, re.I)
    if not imgs:
        continue
    title = clean_title(ph, txt)
    d = os.path.join(OUT, f"{safe(title)}__jp114-{sid}")
    os.makedirs(d, exist_ok=True)
    n = 0
    for iu in dict.fromkeys(imgs):
        try:
            data = fetch("https:" + iu if iu.startswith("//") else iu, binary=True)
        except Exception:
            continue
        if len(data) < 3000:
            continue
        ext = ".png" if data[:4] == b"\x89PNG" else (".gif" if data[:3] == b"GIF" else ".jpg")
        with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
            g.write(data)
        n += 1
        time.sleep(0.2)
    if n:
        ok += 1
    else:
        try:
            os.rmdir(d)
        except OSError:
            pass
    if ok % 20 == 0 and ok:
        print(f"   已下 {ok} 首(跳过已有 {skipped})", flush=True)
    time.sleep(0.3)

print(f"完成: {ok} 首(其中原本就有 {skipped}) -> {OUT}", flush=True)
