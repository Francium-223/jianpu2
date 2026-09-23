# -*- coding: utf-8 -*-
"""爬 jianpu.cn(歌谱简谱网) 的曲谱图, 用于补充"流行歌"。

站点是 GBK 编码。入口: 歌手页(/g/xx/yyyy.htm) 列出该歌手全部曲谱;
曲谱页(/pu/NN/NNNNNN.htm) 含图片 URL(/img/...) 与歌手链接。
策略: 从种子曲谱页 -> 歌手页 -> 该歌手全部曲谱 -> 下载图片; 并把新歌手入队(BFS)。

用法: py -3.13 tools/crawl_jianpucn.py [目标曲谱数] [--max-artists N]
输出: images-prep/jianpucn-pop/<清洗后标题>__jianpucn-<id>/001.jpg
"""
import io, os, re, sys, time, urllib.request, urllib.error
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 300
MAX_ARTISTS = 60
if "--max-artists" in sys.argv:
    MAX_ARTISTS = int(sys.argv[sys.argv.index("--max-artists") + 1])

OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")

def safe(name):
    name = re.sub(r"&nbsp;|\s+", " ", name).strip()
    name = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", name)
    return name[:60] or "untitled"

# 种子: 用户给过的《富士山下》页 + 首页列表几个
seeds = ["http://www.jianpu.cn/pu/43/438812.htm"]
try:
    lst = fetch("http://www.jianpu.cn/sanzigepu")
    seeds += ["http://www.jianpu.cn" + u for u in re.findall(r"href='(/pu/\d+/\d+\.htm)'", lst)[:6]]
except Exception as e:
    print("列表页取失败", e)

song_q = list(dict.fromkeys(seeds))
artist_q = []
seen_songs, seen_artists = set(), set()
done = 0

def img_of(html):
    m = re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
    m = [x for x in m if "logo" not in x.lower()]
    return m

while (song_q or artist_q) and done < TARGET:
    if song_q:
        url = song_q.pop(0)
        if url in seen_songs:
            continue
        seen_songs.add(url)
        try:
            html = fetch(url)
        except Exception as e:
            print("  曲谱页失败", url, e); continue
        # 标题
        mt = re.search(r"<title>(.*?)</title>", html, re.S)
        title = safe(mt.group(1).split("_")[0]) if mt else "untitled"
        title = re.sub(r"^.*?[-—]\s*", "", title) if title.count("-") > 0 else title
        sid = re.search(r"/(\d+)\.htm", url).group(1)
        imgs = img_of(html)
        if imgs:
            d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
            os.makedirs(d, exist_ok=True)
            ok = 0
            for i, iu in enumerate(imgs[:3]):
                fn = os.path.join(d, f"00{i+1}.jpg")
                if os.path.exists(fn):
                    ok += 1; continue
                try:
                    req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
                    with urllib.request.urlopen(req, timeout=25) as r, open(fn, "wb") as g:
                        g.write(r.read())
                    ok += 1
                except Exception:
                    pass
                time.sleep(0.3)
            if ok:
                done += 1
                print(f"[{done}/{TARGET}] {title[:34]}  ({ok} 图)", flush=True)
        # 歌手链接 + 相关曲谱
        for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", html):
            if a not in seen_artists and len(artist_q) < MAX_ARTISTS:
                artist_q.append("http://www.jianpu.cn" + a)
        for s in re.findall(r"href='(/pu/\d+/\d+\.htm)'", html):
            if s not in seen_songs:
                song_q.append("http://www.jianpu.cn" + s)
        time.sleep(0.4)
    elif artist_q:
        aurl = artist_q.pop(0)
        if aurl in seen_artists:
            continue
        seen_artists.add(aurl)
        try:
            html = fetch(aurl)
        except Exception as e:
            print("  歌手页失败", aurl, e); continue
        cnt = 0
        for s in re.findall(r"href='(/pu/\d+/\d+\.htm)'", html):
            if s not in seen_songs:
                song_q.append("http://www.jianpu.cn" + s)
                cnt += 1
        print(f"  [歌手页] {aurl.split('/')[-1]}  新增 {cnt} 曲", flush=True)
        time.sleep(0.4)

print(f"\n共下载 {done} 个曲谱 -> {OUT}")
