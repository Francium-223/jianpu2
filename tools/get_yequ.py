# -*- coding: utf-8 -*-
"""从 jianpu.cn 下载指定的曲谱页到 images-prep/jay-chou/。"""
import os, re, sys, time, urllib.request
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
OUT = "images-prep/jay-chou"
PAGES = [
    ("/pu/11/115143.htm", "夜曲 歌曲类 简谱"),
    ("/pu/90/90797.htm", "夜曲 A"),
    ("/pu/35/35562.htm", "夜曲 B"),
    ("/pu/10/102923.htm", "夜曲-弹唱版-巴特尔"),
    ("/pu/11/112766.htm", "夜曲 钢琴伴奏谱"),
]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60]


os.makedirs(OUT, exist_ok=True)
for path, label in PAGES:
    sid = re.search(r"/(\d+)\.htm", path).group(1)
    url = "http://www.jianpu.cn" + path
    try:
        html = fetch(url)
    except Exception as e:
        print(f"  {label}: 页面失败 {e}")
        continue
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
    title = safe(m1.group(1)) if m1 else label
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        print(f"  {label}: 页面上没有谱图")
        continue
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    os.makedirs(d, exist_ok=True)
    n = 0
    for i, iu in enumerate(imgs[:2]):
        fn = os.path.join(d, f"00{i+1}.jpg")
        try:
            req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r, open(fn, "wb") as g:
                g.write(r.read())
            n += 1
        except Exception:
            pass
        time.sleep(0.25)
    print(f"  {label}: 下载 {n} 张 -> {os.path.basename(d)}")
    time.sleep(0.4)
print("\n完成。目录:", OUT)
