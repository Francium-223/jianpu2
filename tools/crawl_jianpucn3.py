# -*- coding: utf-8 -*-
"""爬 jianpu.cn 曲谱图(补充流行歌)。不做类型过滤 —— 五线谱/吉他谱转不出简谱音符,
会被管线自然筛掉。标题取 <h1>(干净, 不含站点后缀)。
用法: py -3.13 tools/crawl_jianpucn3.py [目标数] [每类页数]
"""
import os, re, sys, time, urllib.request
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
PAGES = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 10
OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)
CATS = ["sanzigepu", "sizigepu", "wuzigepu", "liuzigepu", "qizigepu",
        "bazigepu", "jiuzigepu", "shizijiyishang", "erzigepu"]

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")

def safe(s):
    s = re.sub(r"&nbsp;|\s+", " ", s).strip()
    s = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", s)
    return re.sub(r"_{2,}", "_", s)[:60] or "untitled"

urls = []
for cat in CATS:
    for p in range(1, PAGES + 1):
        u = f"http://www.jianpu.cn/{cat}" + ("" if p == 1 else f"/{p}.htm")
        try:
            html = fetch(u)
        except Exception:
            continue
        urls += re.findall(r"href='(/pu/\d+/\d+\.htm)'", html)
        time.sleep(0.2)
    urls = list(dict.fromkeys(urls))
    print(f"  {cat}: 候选 {len(urls)}", flush=True)
    if len(urls) >= TARGET * 2:
        break

print(f"候选 {len(urls)}, 开始下载 {TARGET}")
done = fail = 0
for u in urls:
    if done >= TARGET:
        break
    sid = re.search(r"/(\d+)\.htm", u).group(1)
    try:
        html = fetch("http://www.jianpu.cn" + u)
    except Exception:
        continue
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
    title = safe(m1.group(1)) if m1 else safe(u)
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    if os.path.isdir(d) and any(f.endswith(".jpg") for f in os.listdir(d)):
        done += 1; continue
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        fail += 1; continue
    os.makedirs(d, exist_ok=True)
    ok = 0
    for i, iu in enumerate(imgs[:2]):
        try:
            req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r, open(os.path.join(d, f"00{i+1}.jpg"), "wb") as g:
                g.write(r.read())
            ok += 1
        except Exception:
            pass
        time.sleep(0.2)
    if ok:
        done += 1
        if done % 25 == 0:
            print(f"[{done}/{TARGET}] {title[:36]}", flush=True)
    time.sleep(0.25)

print(f"\n完成: {done} 个 (无图 {fail}) -> {OUT}")
