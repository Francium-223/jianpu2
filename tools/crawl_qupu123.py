# -*- coding: utf-8 -*-
"""爬 qupu123(中国曲谱网) 的曲谱 —— 实测图片 2480x3507 (A4@300dpi), 是最清晰的源。

结构:
  检索    https://www.qupu123.com/Search?keys=<关键词>
  曲谱页  https://www.qupu123.com/<section>/<sub>/p<id>.html
  图片    https://www.qupu123.com/Public/Uploads/YYYY/MM/DD/<hash>.jpg  (通常 2480x3507)

路径取舍:
  /tongsu/  通俗(流行)简谱   -> 收 ✓ (主要目标)
  /jipu/    吉他谱           -> 收(带六线谱, 会被纯度门过滤, 但偶有简谱)
  /qiyue/   器乐谱           -> 跳过 ✗

用法:
  py tools/crawl_qupu123.py 周杰伦 200
"""
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import tlsfetch                                     # noqa: E402  取页 + 证书过期兜底
from crawl_limits import pages, throttle            # noqa: E402  谱图页数上限 + 统一限速(>=1 秒/请求)

# --help 保护: 这三个爬虫没有 argparse, 万一被当冒烟测试跑起来会**真的开始下载** —— 直接打文档退出。
if any(a in ("-h", "--help") for a in sys.argv[1:]):
    print(__doc__)
    raise SystemExit(0)


UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
KEY = sys.argv[1] if len(sys.argv) > 1 else "周杰伦"
TARGET = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 120
# 目录名用显式 ASCII 短名(第3个参数), 否则用关键词的 ascii 化结果 ——
# 别用 urlquote 结果当目录名(会变成 qupu123-E591A8... 这种乱码)
_slug = sys.argv[3] if len(sys.argv) > 3 else re.sub(r"[^0-9A-Za-z]", "", KEY)
SLUG = _slug[:24] or "kw"
# 图库落在**工作区**的 `images-prep/`(旧的 8.9GB 图库就在那儿, 单一存储);
# 用 JIANPU_IMAGES 可以指到别处。
# ⚠ 2026-10-06 修: 这里原来自己算 `dirname(dirname(dirname(__file__)))` 当"工作区", 得出的是
# `D:\Documents_D` —— **仓库外面**, 而图库一直在 `jianpu2/images-prep`(`jp_root.images_root()`
# 的注释里记着同一件事, 当时修了别的 7 个脚本, 漏了这个)。于是本爬虫一旦跑起来, 新图会散到
# 仓库外面去, 或对着一堆不存在的目录空转。改成与全仓**同一口径**的唯一入口。
from jp_root import images_root                     # noqa: E402
IMG_ROOT = images_root()
OUT = os.path.join(IMG_ROOT, f"qupu123-{SLUG}")
os.makedirs(OUT, exist_ok=True)


def get(url, binary=False, timeout=30):
    # 统一限速: >=1 秒/请求(见 tools/crawl_limits.py)。原来本族是 0.15/0.25 秒, 而 jianpucn
    # 族是 1.0 秒 —— 同一个项目里两套节奏, 这里收敛到一处。
    throttle()
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "https://www.qupu123.com/"})
    # tlsfetch: qupu123 的证书 2026-09-23 到期, 严格校验会直接失败(以前被误当成"站点反爬/打不开")。
    # 它先正常校验, 只有真的证书错误才对这个 host 放开一次重试。
    with tlsfetch.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


# 本文件所在目录(tools/) —— 取共用模块 `corpus_index` 用; 上面那行 `sys.path.insert(0, "tools")`
# 是靠"先 chdir 到仓库根"才对上的, 这里不依赖 cwd。
_TOOLS = os.path.dirname(os.path.abspath(__file__))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本爬虫原来只按"图目录在不在"判已抓过(`os.path.isdir(d) and os.listdir(d)`), 而图目录与语料
    是两套账: 同一首歌从别的源抓过、或者转过写之后目录被挪过的, 都会再抓一遍再进一次转写队列
    (2026-10-04 实测那一轮 1764 条队列几乎全是重复, 净增 1 首)。曲名/站内 id 命中语料就跳过。
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


# 1) 检索并翻页
items = []
for page in range(1, 12):
    url = f"https://www.qupu123.com/Search?keys={urllib.parse.quote(KEY)}&page={page}"
    try:
        h = get(url)
    except Exception:
        break
    found = re.findall(r'href="(/[^"]+?/p(\d+)\.html)"[^>]*>([^<]{2,90})</a>', h)
    keep = [(u, i, t.strip()) for u, i, t in found if not u.startswith("/qiyue/")]
    new = [(u, i, t) for u, i, t in keep if i not in {x[1] for x in items}]
    if not new:
        break
    items.extend(new)
    print(f"  检索第 {page} 页: +{len(new)} (累计 {len(items)})", flush=True)
    if len(items) >= TARGET:
        break
    # 限速已由 get() 里的 throttle() 统一负责。

items = items[:TARGET]
print(f"\n{KEY}: {len(items)} 个曲谱页, 开始下载")

ok = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
for i, (path, sid, title) in enumerate(items, 1):
    # 语料里已有 -> 跳过(站内 id 或曲名), 连曲谱页都不请求
    if _ci is not None:
        r = _ci.skip_reason("qupu123", sid, title)
        if r:
            skipped.count(r)
            if r == "title":
                skipped.note_title_skip(title[:44])
            continue
    d = os.path.join(OUT, f"{safe(title)}__qupu123-{sid}")
    if os.path.isdir(d) and os.listdir(d):
        ok += 1
        continue
    try:
        ph = get("https://www.qupu123.com" + path)
    except Exception:
        continue
    # 图片 src 是**相对路径**(/Public/Uploads/...), 必须用 urljoin 补全 ——
    # 之前写成要求带 https://www.qupu123.com 前缀, 结果一张都匹配不到(下载 0 首)。
    imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
    imgs = [urllib.parse.urljoin("https://www.qupu123.com/", x) for x in dict.fromkeys(imgs)]
    # **两种图床都要收**(2026-09-22 实测): 老谱在 /Public/Uploads/, 但新上传的在 /data2/uploads/
    # —— 只认前者会把《新长征路上的摇滚》(/data2/uploads/2026/05/06/*.jpg, 2192x3508) 整首丢掉。
    imgs = [x for x in imgs if "/Public/Uploads/" in x or "/data2/uploads/" in x]
    if not imgs:
        continue
    os.makedirs(d, exist_ok=True)
    n = 0
    # 2026-10-06 修: 原来写死 `imgs[:6]` —— 硬截断会缺页(实测 jianpu.cn 的详情页最多 6 张,
    # qupu123 这边也见过 6 张以上的目录)。默认全部, 可用 `JIANPU_MAX_PAGES` 给上限。
    for iu in pages(imgs):
        try:
            data = get(iu, binary=True)
        except Exception:
            continue
        if len(data) < 8000:      # 太小的是装饰图
            continue
        # 页面上有 750x55 这类横幅装饰图, 会混进来 —— 按"短边>=400"过滤掉
        try:
            from PIL import Image as _I
            import io as _io
            _im = _I.open(_io.BytesIO(data))
            if min(_im.size) < 400:
                continue
        except Exception:
            pass
        ext = ".png" if data[:4] == b"\x89PNG" else ".jpg"
        with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
            g.write(data)
        n += 1
    if n:
        ok += 1
        if ok % 20 == 0:
            print(f"  [{ok}/{len(items)}] {title[:40]}", flush=True)
    # 限速已由 get() 里的 throttle() 统一负责(原来这里还各自 sleep 0.25 秒)。

print(f"\n完成: {ok} 首 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
