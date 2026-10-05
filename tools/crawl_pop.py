# -*- coding: utf-8 -*-
"""爬 jianpu.cn 的流行歌曲(歌手页路线, 避免漂移)。

  * 相关曲谱链接: **只用于发现歌手**, 不下载(否则会漂到莫扎特/练习曲)
  * 下载来源: 歌手页里该歌手的**全部作品**, 且只扩"作品数>=MIN_SONGS"的歌手(名人)
用法: py -3.13 tools/crawl_pop.py [目标数] [最大歌手数]
"""
import glob, os, re, sys, time, urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from crawl_limits import pages       # noqa: E402  谱图页数上限: 默认不截断(见 tools/crawl_limits.py)
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


# 相关曲谱的锚点正文里, 方括号装的是**分类名**(2026-10-06 实测):
#   `[三字歌谱]推车歌  焦洋`、`[十字及以上]…`、`[钢琴谱]夜曲  肖邦`、`[吉他谱]夜曲  周杰伦`
# (`<a href='/pu/47/475917.htm' >[三字歌谱]推车歌&nbsp;&nbsp;焦洋</a>`)。
# 注意**分类页列表**里方括号装的是歌手(`[邓紫棋] 画`), 两处不是一回事。
# 旧判据 `"简谱" in txt` 找的是改版前的 `[简谱]` 类型标签 —— 实测一条都筛不出来
# (整页出现 5 次 "简谱" 全在正文别处), 于是 discover 队列永远不增长、跑几首就"结束"。
# 中文名与路径的对应取自站点首页一级导航(一字歌谱..九字歌谱/十字及以上/合唱谱/英文歌谱)。
REL_CAT = re.compile(r"^\s*\[([^\]]+)\]")
JIANPU_CATS_CN = ("一字歌谱", "二字歌谱", "三字歌谱", "四字歌谱", "五字歌谱", "六字歌谱",
                  "七字歌谱", "八字歌谱", "九字歌谱", "十字及以上", "合唱谱", "英文歌谱")


def is_jianpu_rel(txt):
    """相关曲谱锚点正文 -> 是不是**简谱类**的谱(`[三字歌谱]推车歌  焦洋` -> True)。"""
    m = REL_CAT.match(txt or "")
    return bool(m) and m.group(1) in JIANPU_CATS_CN


def save_song(url, title):
    sid = re.search(r"/(\d+)\.htm", url).group(1)
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    if os.path.isdir(d) and any(f.endswith(".jpg") for f in os.listdir(d)):
        return True
    try:
        html = fetch(url)
    except Exception:
        return False
    # 谱图地址(2026-10-06 实测): 老页 `/img/8f/bc/<hash>.gif`, 2025 起新页 `/img9/2/kv/<hash>.jpg`
    # —— 旧写法 `/img/` 对新页 **0 命中**, 于是保存函数一律返回 False("保存不了"却看不出原因)。
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        return False
    os.makedirs(d, exist_ok=True)
    ok = 0
    # 2026-10-06 修: 原来写死 `imgs[:2]` —— 实测详情页最多有 6 张(《93海阔天空》), 只存 2 张
    # 会让后面几页**永远下不到**。默认全部(可用 `JIANPU_MAX_PAGES` 给上限)。
    for i, iu in enumerate(pages(imgs)):
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
                    if is_jianpu_rel(m.group(2)) and m.group(1) not in seen_s:
                        discover.append("http://www.jianpu.cn" + m.group(1))
                # 歌手链接有 `/g/BE/BEYOND.htm` 这种大写形态(2026-10-06 实测), 必须带 re.I
                for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", h2, re.I):
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
        # 歌手链接有 `/g/BE/BEYOND.htm` 这种大写形态(2026-10-06 实测), 必须带 re.I
        for a in re.findall(r"href='(/g/[a-z]{2}/[a-z0-9]+\.htm)'", html, re.I):
            if a not in seen_a and len(artist_q) < MAX_ART:
                artist_q.append("http://www.jianpu.cn" + a)
        # 相关曲谱只用来继续发现歌手。**只跟简谱类的谱** —— 相关列表里每条都带**分类名**
        # (实测 `[三字歌谱]推车歌  焦洋`); 跟着钢琴谱/吉他谱走会漂到古典
        # (实测顺着陈奕迅的钢琴伴奏谱滚到了莫扎特 185 部), 所以按分类名白名单筛, 见 `is_jianpu_rel`。
        for m in re.finditer(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{0,60})", html):
            s, txt = m.group(1), m.group(2)
            if not is_jianpu_rel(txt):
                continue
            if s not in seen_s:
                discover.append("http://www.jianpu.cn" + s)
        time.sleep(0.3)

print(f"\n完成 {done} -> {OUT}")
