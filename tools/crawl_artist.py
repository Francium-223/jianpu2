# -*- coding: utf-8 -*-
"""爬指定歌手页的所有曲谱(jianpu.cn)。

用法: py tools/crawl_artist.py <歌手页URL> [目标数]
       py tools/crawl_artist.py http://www.jianpu.cn/g/zh/zhoujielun.htm 600

为什么需要它: crawl_pop.py 是顺着"相关链接"发现歌手的, 会漏掉大牌
(实测周杰伦 1257 首一首都没爬到)。拿到歌手页 URL 就能整页抓。
输出: images-prep/<歌手拼音>/<标题>__jianpucn-<id>/
"""
import os, re, sys, time, urllib.request
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

URL = sys.argv[1] if len(sys.argv) > 1 else "http://www.jianpu.cn/g/zh/zhoujielun.htm"
TARGET = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 400
slug = re.sub(r"[^a-z0-9]", "", os.path.basename(URL).replace(".htm", "")) or "artist"
OUT = os.path.join("images-prep", f"jianpucn-{slug}")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


os.makedirs(OUT, exist_ok=True)
print(f"歌手页: {URL}\n输出目录: {OUT}")
try:
    html = fetch(URL)
except Exception as e:
    print("歌手页取失败:", e); sys.exit(1)
links = list(dict.fromkeys(re.findall(r"href='(/pu/\d+/\d+\.htm)'", html)))
print(f"该页曲谱链接: {len(links)} 个, 目标抓 {TARGET}")

done = 0
for path in links:
    if done >= TARGET:
        break
    sid = re.search(r"/(\d+)\.htm", path).group(1)
    d = os.path.join(OUT, f"tmp-{sid}")
    if any(x.startswith(f"{sid}") for x in os.listdir(OUT) if False):
        pass
    # 已存在则跳过(按 id 判)
    if any(sid in name for name in os.listdir(OUT)):
        done += 1
        continue
    try:
        h = fetch("http://www.jianpu.cn" + path)
    except Exception:
        continue
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", h, re.S)
    title = safe(m1.group(1)) if m1 else f"untitled-{sid}"
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", h, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        continue
    dd = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    os.makedirs(dd, exist_ok=True)
    ok = 0
    for i, iu in enumerate(imgs[:2]):
        try:
            req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r, open(os.path.join(dd, f"00{i+1}.jpg"), "wb") as g:
                g.write(r.read())
            ok += 1
        except Exception:
            pass
        time.sleep(0.2)
    if ok:
        done += 1
        if done % 25 == 0:
            print(f"  [{done}/{TARGET}] {title[:36]}", flush=True)
    time.sleep(0.25)
print(f"\n完成: {done} 首 -> {OUT}")
