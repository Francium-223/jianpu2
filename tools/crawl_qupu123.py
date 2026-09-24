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

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
KEY = sys.argv[1] if len(sys.argv) > 1 else "周杰伦"
TARGET = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 120
# 目录名用显式 ASCII 短名(第3个参数), 否则用关键词的 ascii 化结果 ——
# 别用 urlquote 结果当目录名(会变成 qupu123-E591A8... 这种乱码)
_slug = sys.argv[3] if len(sys.argv) > 3 else re.sub(r"[^0-9A-Za-z]", "", KEY)
SLUG = _slug[:24] or "kw"
# 图库落在**工作区**的 `images-prep/`(旧的 8.9GB 图库就在那儿, 单一存储);
# 用 JIANPU_IMAGES 可以指到别处。以前是相对 cwd 的 "images-prep" —— 而本脚本会 chdir 到 jianpu2/,
# 于是新爬的图跑进 jianpu2/images-prep/, 跟工作区那份**劈成了两个库**(2026-09-25 发现并修)。
_WS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # 工作区(三个 dirname: tools/x.py -> tools -> jianpu2 -> 工作区)
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or os.path.join(_WS, "images-prep")
OUT = os.path.join(IMG_ROOT, f"qupu123-{SLUG}")
os.makedirs(OUT, exist_ok=True)


def get(url, binary=False, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Referer": "https://www.qupu123.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


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
    time.sleep(0.3)

items = items[:TARGET]
print(f"\n{KEY}: {len(items)} 个曲谱页, 开始下载")

ok = 0
for i, (path, sid, title) in enumerate(items, 1):
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
    for iu in imgs[:6]:
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
        time.sleep(0.15)
    if n:
        ok += 1
        if ok % 20 == 0:
            print(f"  [{ok}/{len(items)}] {title[:40]}", flush=True)
    time.sleep(0.25)

print(f"\n完成: {ok} 首 -> {OUT}")
