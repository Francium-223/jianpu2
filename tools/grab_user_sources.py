# -*- coding: utf-8 -*-
"""收下用户给的 4 个补充源(天地龙鳞 / 暮色回响 / 不将就 / 爱情讯息), 下到 images-prep 目录。

四种形态:
  ① jianpujia 谱页  -> 从页面里抽 /uploads 或图片直链
  ② 图片直链(png)   -> 直接下
  ③ 短链(lupipi.com/s/xxx) -> 先跟随重定向看落地页, 再按页面类型抽图
"""
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
OUT = "images-prep/user-supplied"
os.makedirs(OUT, exist_ok=True)

TARGETS = [
    ("天地龙鳞", "https://www.jianpujia.com/jianpu/257591.html"),
    ("暮色回响", "https://y.milianshe.cn/uploads/ossweb/2024-11/17/17318336084526.png"),
    ("不将就", "https://lupipi.com/s/cdefa5"),
    ("爱情讯息", "https://lupipi.com/s/2097d6"),
]


def fetch(u, to=30):
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=to, context=CTX) as r:
        return r.read(), r.geturl(), r.headers.get("Content-Type", "")


for title, url in TARGETS:
    d = os.path.join(OUT, f"{title}__user")
    if os.path.isdir(d) and os.listdir(d):
        print(f"[已有] {title}")
        continue
    try:
        b, final_url, ctype = fetch(url)
    except Exception as e:
        print(f"[失败] {title}  {type(e).__name__} {str(e)[:70]}  {url}")
        continue
    print(f"[抓取] {title}  {len(b)} 字节  ctype={ctype[:30]}  最终URL={final_url[:80]}")
    os.makedirs(d, exist_ok=True)
    n = 0

    if "image" in ctype or re.search(r"\.(png|jpe?g|gif|webp)$", final_url, re.I):
        ext = ".png" if "png" in ctype or final_url.lower().endswith(".png") else ".jpg"
        with open(os.path.join(d, f"001{ext}"), "wb") as g:
            g.write(b)
        n = 1
    else:
        h = b.decode("utf-8", "replace")
        # 候选图: 绝对/相对图片链, 排除 logo/图标; 也看 <img data-src>
        cands = []
        for m in re.finditer(r'(?:data-src|data-original|src)="([^"]+?\.(?:jpg|jpeg|png|gif|webp))"', h, re.I):
            u2 = urllib.parse.urljoin(final_url, m.group(1))
            if re.search(r"logo|icon|avatar|qrcode|ewm|banner", u2, re.I):
                continue
            cands.append(u2)
        cands = list(dict.fromkeys(cands))
        print(f"        页面里找到 {len(cands)} 个候选图: {[c[-46:] for c in cands[:4]]}")
        for u2 in cands[:6]:
            try:
                data, _fu, ct2 = fetch(u2, 30)
            except Exception as e:
                print(f"        图失败 {type(e).__name__} {u2[-50:]}")
                continue
            if len(data) < 8000:          # 太小的基本是图标/占位
                continue
            ext = os.path.splitext(urllib.parse.urlparse(u2).path)[1] or ".jpg"
            with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
                g.write(data)
            n += 1
            time.sleep(0.2)
    print(f"       -> 下到 {n} 张 -> {d}")
    time.sleep(0.3)
