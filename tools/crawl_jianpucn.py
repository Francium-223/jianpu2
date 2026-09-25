# -*- coding: utf-8 -*-
"""爬 jianpu.cn(歌谱简谱网) 的曲谱图, 用于补充"流行歌" —— 库里最大的来源(3,215 首)。

站点是 GBK 编码。入口:
  * 歌手页 `/g/xx/yyyy.htm` —— 列出该歌手**全部**曲谱(这是扩量的主力入口);
  * 曲谱页 `/pu/NN/NNNNNN.htm` —— 含图片 URL(`/img/...`, **单引号**)与该曲的歌手链接。
策略: 种子曲谱页 -> 歌手页 -> 该歌手全部曲谱 -> 下载图片; 新歌手、相关曲谱继续入队(BFS)。

2026-09-25 夜间改造:
  * **断点续爬**: 访问过的曲谱/歌手页与两条队列写进状态文件(默认 `_analysis/crawl_state_jianpucn.json`),
    重启不重抓(以前每次从头来过, 只靠"文件已存在就跳过"省下载);
  * **种子换成语料里 source=jianpucn-* 的页面** —— 保证是"我们要的那类歌", 再由歌手页铺开;
  * 图库统一落**工作区** `images-prep/`(`JIANPU_IMAGES` 可覆盖; 以前写相对路径, 靠 jianpu2/images-prep
    那个软链才对上, 现在显式写清楚)。

用法:
    python3 tools/crawl_jianpucn.py 1500 --max-artists 300        # 抓 1500 首, 最多铺 300 个歌手
    python3 tools/crawl_jianpucn.py 50 --seeds 438812 150657      # 只用这些曲谱 id 当种子
"""
import io
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                        # jianpu2
WS = os.path.dirname(ROOT)                          # 工作区
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
IMG_ROOT = os.environ.get("JIANPU_IMAGES") or os.path.join(WS, "images-prep")
OUT = os.path.join(IMG_ROOT, "jianpucn-pop")
STATE = os.path.join(WS, "_analysis", "crawl_state_jianpucn.json")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
BASE = "http://www.jianpu.cn"


def fetch(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=25) as r:
        raw = r.read()
    return raw if binary else raw.decode("gbk", errors="replace")


def safe(name):
    name = re.sub(r"&nbsp;|\s+", " ", name).strip()
    name = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", name)
    return name[:60] or "untitled"


def img_of(html):
    """谱图: 单双引号都要认(站点用单引号), 排除 logo/广告。"""
    m = re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
    return [x for x in m if "logo" not in x.lower()]


def corpus_seed_pages(limit):
    """语料里 source=jianpucn-<id> 的页面当种子 —— 保证是"我们要的那类歌"。"""
    out, p = [], os.path.join(DB, "data.jsonl")
    if not os.path.isfile(p):
        return out
    for ln in io.open(p, encoding="utf-8"):
        r = json.loads(ln)
        for s in (r.get("source") or []):
            if s.startswith("jianpucn-"):
                sid = s.split("-", 1)[1]
                out.append("%s/pu/%s/%s.htm" % (BASE, sid[:len(sid) - 4] or sid[:2], sid))
                break
        if len(out) >= limit:
            break
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    args = sys.argv[1:]
    target = int(args[0]) if args and args[0].isdigit() else 300
    max_artists = 300
    if "--max-artists" in args:
        max_artists = int(args[args.index("--max-artists") + 1])
    seeds = []
    if "--seeds" in args:
        for sid in args[args.index("--seeds") + 1:]:
            if not sid.isdigit():
                break
            seeds.append("%s/pu/%s/%s.htm" % (BASE, sid[:len(sid) - 4] or sid[:2], sid))
    if not seeds:
        seeds = corpus_seed_pages(300) or ["%s/pu/43/438812.htm" % BASE]

    os.makedirs(OUT, exist_ok=True)
    st = {"songs_seen": [], "artists_seen": [], "song_q": [], "artist_q": [], "done": 0}
    if os.path.isfile(STATE):
        try:
            st.update(json.load(io.open(STATE, encoding="utf-8")))
        except Exception:
            pass
    song_q = list(dict.fromkeys(list(st.get("song_q") or []) + seeds))
    artist_q = list(st.get("artist_q") or [])
    seen_songs = set(st.get("songs_seen") or [])
    seen_artists = set(st.get("artists_seen") or [])
    done = int(st.get("done") or 0)
    print(f"目标 {target} 首(本次) · 队列: 曲谱 {len(song_q)} / 歌手 {len(artist_q)} · "
          f"已访问 曲谱 {len(seen_songs)} / 歌手 {len(seen_artists)} · 输出 {OUT}", flush=True)

    def save():
        json.dump({"songs_seen": sorted(seen_songs)[-40000:], "artists_seen": sorted(seen_artists)[-5000:],
                   "song_q": song_q[:8000], "artist_q": artist_q[:2000], "done": done},
                  io.open(STATE, "w", encoding="utf-8"), ensure_ascii=False)

    got = 0
    while (song_q or artist_q) and got < target:
        if song_q:
            url = song_q.pop(0)
            if url in seen_songs:
                continue
            seen_songs.add(url)
            try:
                html = fetch(url)
            except Exception:
                continue
            mt = re.search(r"<title>(.*?)</title>", html, re.S)
            title = safe(re.sub(r"\s*歌谱简谱网\s*$", "", mt.group(1)).strip()) if mt else "untitled"
            sid = re.search(r"/(\d+)\.htm", url).group(1)
            imgs = img_of(html)
            if imgs:
                d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
                os.makedirs(d, exist_ok=True)
                ok = 0
                for i, iu in enumerate(imgs[:3]):
                    ext = os.path.splitext(iu)[1].lower() or ".jpg"
                    fn = os.path.join(d, "00%d%s" % (i + 1, ext))
                    if os.path.exists(fn):
                        ok += 1
                        continue
                    try:
                        data = fetch(BASE + iu, binary=True)
                        if len(data) < 8000:
                            continue
                        with open(fn, "wb") as g:
                            g.write(data)
                        ok += 1
                    except Exception:
                        pass
                    time.sleep(0.3)
                if ok:
                    got += 1
                    done += 1
                    print(f"  [{got}/{target}] {title[:30]:<32} {ok} 图", flush=True)
            for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", html):
                full = BASE + a
                if (full not in seen_artists and full not in artist_q
                        and len(seen_artists) + len(artist_q) < max_artists):
                    artist_q.append(full)
            for s in re.findall(r"href='(/pu/\d+/\d+\.htm)'", html):
                full = BASE + s
                if full not in seen_songs and full not in song_q:
                    song_q.append(full)
            time.sleep(0.4)
        else:
            aurl = artist_q.pop(0)
            if aurl in seen_artists:
                continue
            seen_artists.add(aurl)
            try:
                html = fetch(aurl)
            except Exception:
                continue
            cnt = 0
            for s in re.findall(r"href='(/pu/\d+/\d+\.htm)'", html):
                full = BASE + s
                if full not in seen_songs and full not in song_q:
                    song_q.append(full)
                    cnt += 1
            print(f"  [歌手页] {aurl.split('/')[-1]:<16} 新增 {cnt} 曲", flush=True)
            time.sleep(0.4)
        if len(seen_songs) % 20 == 0:
            save()
    save()
    print(f"\n本次新下 {got} 首(累计 {done}); 已访问 曲谱 {len(seen_songs)} / 歌手 {len(seen_artists)}; "
          f"队列还剩 曲谱 {len(song_q)} / 歌手 {len(artist_q)}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
