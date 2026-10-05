# -*- coding: utf-8 -*-
"""用 qupu123 **站内搜索**按曲名把谱页找出来并下载(比翻目录页快得多)。

为什么另写一个: 现有 crawl_qupu123_by_title.py 是"逐页翻分类目录"的做法, 目标曲名要等翻到
那一页才命中(实测 98 首里漏了 8 首老歌, 而站内搜索一次就全找到 —— 等一分钟/爱错/特别的人/
雨爱/下一个天亮/爱我还是他/猜不透/最后一页 全有)。搜索页里就是谱页链接, 直接取前 N 条。

用法: py -3.13 tools/crawl_qupu123_search.py "歌名1,歌名2" [每首最多下几个=3]
"""
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request
import tlsfetch                                              # 证书过期兜底(qupu123 的证书 2026-09-23 到期)
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
from crawl_limits import pages, throttle     # noqa: E402  谱图页数上限 + 统一限速(>=1 秒/请求)

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
HDR = {"User-Agent": UA, "Referer": "https://www.qupu123.com/"}
OUT = "images-prep/qupu123-search"
os.makedirs(OUT, exist_ok=True)

WANT = [x.strip() for x in (sys.argv[1].split(",") if len(sys.argv) > 1 else []) if x.strip()]
PER = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 3
if not WANT:
    sys.exit(__doc__)


def get(u, to=25):
    throttle()                   # 统一限速: >=1 秒/请求(原来本族是 0.15/0.2 秒)
    req = urllib.request.Request(u, headers=HDR)
    with tlsfetch.urlopen(req, timeout=to) as r:
        return r.read()


def safe(s):
    return re.sub(r"\s+", " ", re.sub(r'[\\/:*?"<>|\x00-\x1f]', "_", s)).strip()[:60] or "untitled"


# 本文件所在目录(tools/) —— 取共用模块 `corpus_index` 用(不依赖 cwd)
_TOOLS = os.path.dirname(os.path.abspath(__file__))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本脚本原来只按"图目录在不在"判已抓过, 而图目录与语料是两套账: 同一首歌从别的源抓过、
    或转过写之后目录被挪过的都会再抓一遍(2026-10-04 实测: 一轮 1764 条转写队列几乎全是重复)。
    导入失败照常抓 —— 宁可多下, 不要因为索引坏了整轮空转。
    """
    try:
        if _TOOLS not in sys.path:
            sys.path.insert(0, _TOOLS)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None


ok = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
for t in WANT:
    # 曲名已在语料里 -> 连搜索都省了
    if _ci is not None and _ci.title_in_corpus(t):
        skipped.count("title")
        skipped.note_title_skip(t)
        continue
    u = "https://www.qupu123.com/Search?keys=" + urllib.parse.quote(t)
    try:
        h = get(u).decode("utf-8", "replace")
    except Exception as e:
        print(f"  搜索失败 {t}: {type(e).__name__}", flush=True)
        continue
    # 谱页链接 + 标题(url 必须含 p<id>.html)
    items = re.findall(r'href="(/[a-z]+/(?:[a-z]+/)?p(\d+)\.html)"[^>]*>([^<]{1,60})<', h)
    # **只收同名**(歌名是标题的前缀或整体包含), 挡掉"冬天"这类泛词误命中
    keep = [(p, i, ti.strip()) for p, i, ti in items if ti.strip().startswith(t) or t in ti.strip()]
    if not keep:
        print(f"  未命中 {t} (搜索返回 {len(items)} 条链接, 无同名)", flush=True)
        continue
    got = 0
    for path, sid, ti in keep[:PER]:
        # 命中结果的站内 id / 标题在语料里 -> 跳过这一条
        if _ci is not None:
            r = _ci.skip_reason("qupu123", sid, ti)
            if r:
                skipped.count(r)
                if r == "title":
                    skipped.note_title_skip(ti[:44])
                continue
        d = os.path.join(OUT, f"{safe(ti)}__qupu123-{sid}")
        if os.path.isdir(d) and os.listdir(d):
            got += 1
            continue
        try:
            ph = get("https://www.qupu123.com" + path).decode("utf-8", "replace")
        except Exception:
            continue
        imgs = [x for x in dict.fromkeys(re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I))
                if "/Public/Uploads/" in x or "/data2/uploads/" in x]
        if not imgs:
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        # 2026-10-06 修: 原来写死 `imgs[:6]` —— 硬截断会缺页, 默认改成全部
        # (可用 `JIANPU_MAX_PAGES` 给上限), 见 tools/crawl_limits.py。
        for iu in pages(imgs):
            full = urllib.parse.urljoin("https://www.qupu123.com/", iu)
            try:
                data = get(full, 30)
            except Exception:
                continue
            ext = os.path.splitext(urllib.parse.urlparse(full).path)[1] or ".jpg"
            with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
                g.write(data)
            n += 1
            time.sleep(0.15)
        if n:
            got += 1
            print(f"  + {t} <- {ti[:36]} ({n} 张)", flush=True)
        time.sleep(0.2)
    ok += got
    print(f"  [{t}] 命中 {len(keep)} 个谱页, 下载 {got}", flush=True)
    time.sleep(0.4)

print(f"\n完成: 共下载 {ok} 个谱页 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
