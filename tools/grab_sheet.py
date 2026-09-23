# -*- coding: utf-8 -*-
"""半自动抓谱: 给一个曲谱页 URL, 提取其中的大图并下载到 images-prep/hot-crawl/<曲名>/。

用法: py -3.13 tools/grab_sheet.py <页面URL> <曲名>
"""
import io, os, re, sys, urllib.parse, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PIL import Image

HDR = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/122.0 Safari/537.36",
    "Accept": "text/html,image/*,*/*",
}


def fetch(url):
    req = urllib.request.Request(url, headers=HDR)
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read()


def extract_images(html, base):
    out = []
    for m in re.finditer(r'<img[^>]+?src=["\']([^"\']+)["\']', html, re.I):
        out.append(urllib.parse.urljoin(base, m.group(1)))
    for m in re.finditer(r'<meta[^>]+?property=["\']og:image["\'][^>]+?content=["\']([^"\']+)', html, re.I):
        out.append(urllib.parse.urljoin(base, m.group(1)))
    for m in re.finditer(r'(https?://[^\s"\'<>]+?\.(?:png|jpe?g|webp))', html, re.I):
        out.append(m.group(1))
    # 去重保序
    return list(dict.fromkeys(out))


def main():
    url = sys.argv[1]
    name = sys.argv[2] if len(sys.argv) > 2 else "unknown"
    safe = re.sub(r'[\\/:*?"<>|\s]+', "_", name)
    d = f"images-prep/hot-crawl/{safe}"
    os.makedirs(d, exist_ok=True)
    # **把原页 URL 记在目录里** —— 以前只把曲名当目录名, 原页 URL 丢了, 交付时这几份谱
    # 写不出 `source=`(实测 `不潮不用花钱`/`相思遥` 因此无出处)。谱子必须能说出出处。
    try:
        with open(os.path.join(d, "_source.txt"), "w", encoding="utf-8") as sf:
            sf.write(url + "\n")
    except Exception:
        pass
    print(f"页面: {url}")
    try:
        html = fetch(url).decode("utf-8", "ignore")
    except Exception as e:
        print(f"  页面抓取失败: {type(e).__name__}")
        return
    imgs = extract_images(html, url)
    print(f"  候选图片 {len(imgs)} 个")
    ok = 0
    for u in imgs:
        try:
            b = fetch(u)
            im = Image.open(io.BytesIO(b))
            w, h = im.size
            if w < 400 or h < 400:      # 过滤图标/logo
                continue
            p = os.path.join(d, f"{ok + 1:03d}.jpg")
            im.convert("RGB").save(p, quality=95)
            print(f"  ok {w}x{h}  <- {u[:78]}")
            ok += 1
        except Exception:
            continue
    print(f"  共下载 {ok} 张大图 -> {d}")


if __name__ == "__main__":
    main()
