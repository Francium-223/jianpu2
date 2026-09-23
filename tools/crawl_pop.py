# -*- coding: utf-8 -*-
"""爬 jianpu.cn 的流行歌曲(歌手页路线, 避免漂移)。

  * 相关曲谱链接: **只用于发现歌手**, 不下载(否则会漂到莫扎特/练习曲)
  * 下载来源: 歌手页里该歌手的**全部作品**, 且只扩"作品数>=MIN_SONGS"的歌手(名人)
用法: py -3.13 tools/crawl_pop.py [目标数] [最大歌手数]
"""
import glob, os, re, sys, time, urllib.request
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 120
MAX_ART = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 30
MIN_SONGS = 25          # 作品数下限 = "名人"代理指标
OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")

def safe(s):
    s = re.sub(r"&nbsp;|\s+", " ", s).strip()
    s = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", s)
    return re.sub(r"_{2,}", "_", s)[:60] or "untitled"

def save_song(url, title):
    sid = re.search(r"/(\d+)\.htm", url).group(1)
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    if os.path.isdir(d) and any(f.endswith(".jpg") for f in os.listdir(d)):
        return True
    try:
        html = fetch(url)
    except Exception:
        return False
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        return False
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
    return ok > 0

discover = ["http://www.jianpu.cn/pu/43/438812.htm"]   # 只为发现歌手
artist_q, seen_s, seen_a = [], set(), set()
done = 0

while done < TARGET and (artist_q or discover):
    if artist_q:
        a = artist_q.pop(0)
        if a in seen_a:
            continue
        seen_a.add(a)
        try:
            html = fetch(a)
        except Exception:
            continue
        songs = list(dict.fromkeys(re.findall(r"href='(/pu/\d+/\d+\.htm)'", html)))
        aname = a.split("/")[-1]
        # "未知/佚名"桶(weizhi)有 2 万+ 部杂项(秧歌/考级曲), 不是流行 -> 跳过
        if aname.startswith("weizhi") or aname.startswith("weizhi"):
            print(f"  [跳过未知桶] {aname}", flush=True)
            time.sleep(0.3)
            continue
        if len(songs) < MIN_SONGS:
            print(f"  [跳过小歌手] {aname} (作品{len(songs)})", flush=True)
            time.sleep(0.3)
            continue
        print(f"  [歌手] {aname}  作品 {len(songs)}", flush=True)
        for s in songs:
            if done >= TARGET:
                break
            u = "http://www.jianpu.cn" + s
            if u in seen_s:
                continue
            seen_s.add(u)
            _sid = re.search(r"/(\d+)\.htm", u).group(1)
            _exists = bool(glob.glob(os.path.join(OUT, f"*__jianpucn-{_sid}")))
            try:
                h2 = fetch(u)
            except Exception:
                continue
            # 已存在的歌: 不下载、不计入目标, 但**仍要访问** —— 否则它页面上的
            # "相关曲谱/歌手"链接永远不会被发现, 队列会立刻枯竭
            # (实测: 陈奕迅 319 首全已存在 -> 只拿到 3 首新歌就结束了)。
            if _exists:
                for m in re.finditer(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{0,60})", h2):
                    if "简谱" in m.group(2) and m.group(1) not in seen_s:
                        discover.append("http://www.jianpu.cn" + m.group(1))
                for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", h2):
                    if a not in seen_a and len(artist_q) < MAX_ART:
                        artist_q.append("http://www.jianpu.cn" + a)
                time.sleep(0.25)
                continue
            m1 = re.search(r"<h1[^>]*>(.*?)</h1>", h2, re.S)
            title = safe(m1.group(1)) if m1 else safe(u)
            if save_song(u, title):
                done += 1
                if done % 25 == 0:
                    print(f"     [{done}/{TARGET}] {title[:34]}", flush=True)
            time.sleep(0.3)
    else:
        u = discover.pop(0)
        if u in seen_s:
            continue
        seen_s.add(u)
        try:
            html = fetch(u)
        except Exception:
            continue
        for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", html):
            if a not in seen_a and len(artist_q) < MAX_ART:
                artist_q.append("http://www.jianpu.cn" + a)
        # 相关曲谱只用来继续发现歌手。**只跟 [简谱] 类型** —— 相关列表里每条都带
        # 类型标签(如 "[简谱]富士山下"); 跟着钢琴谱/吉他谱走会漂到古典
        # (实测顺着陈奕迅的钢琴伴奏谱滚到了莫扎特 185 部)。
        for m in re.finditer(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{0,60})", html):
            s, txt = m.group(1), m.group(2)
            if "简谱" not in txt:
                continue
            if s not in seen_s:
                discover.append("http://www.jianpu.cn" + s)
        time.sleep(0.3)

print(f"\n完成 {done} -> {OUT}")
