# -*- coding: utf-8 -*-
"""按 B站播放量给谱图排热度: 优先转写"最可能被搜索"的曲子。
用法: py -3.13 tools/rank_by_bili.py [数量]  -> rank-out/ranked.jsonl + 打印 Top 30
"""
import os, sys, glob, re, json, time, uuid, urllib.parse, urllib.request, statistics
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from to_jianpu_db import title_of

HDR = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/122.0 Safari/537.36",
    "Referer": "https://www.bilibili.com/",
    "Accept": "application/json, text/plain, */*",
    "Cookie": "buvid3=%s-infoc; b_nut=1700000000" % uuid.uuid4(),
}


def clean_song(name):
    """文件名 -> 干净歌名(去 [日] 前缀、去重复段、取主标题)。"""
    t = title_of(name)
    t = re.sub(r"^\[[^\]]{1,3}\]", "", t)
    t = re.split(r"[_\[]", t)[0]
    t = re.sub(r"(简谱|歌谱|钢琴谱|吉他谱|完整版|原调|正谱)", "", t)
    segs = re.findall(r"[A-Za-z][A-Za-z' ]{2,}|[\u4e00-\u9fff]{2,}", t)
    return (segs[0] if segs else t)[:40].strip()


def bili_stats(keyword):
    """搜 B站视频, 返回 (加权热度, 命中数, 代表标题, 中位播放)。
    噪声处理: 标题含"合集/串烧/大全"的视频降权(其播放量是合集的, 不代表该曲);
    标题不含歌名的降权; 歌名过短(<3字)直接判无效(易匹配到无关视频)。"""
    if len(keyword) < 3:
        return 0, 0, "", 0
    url = ("https://api.bilibili.com/x/web-interface/search/type?"
           + urllib.parse.urlencode({"search_type": "video", "keyword": keyword, "page": 1}))
    d = None
    for attempt in range(4):                 # B站 会限流(412/频率), 退避重试
        try:
            req = urllib.request.Request(url, headers=HDR)
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.load(r)
            if d.get("code") == 0:
                break
        except Exception:
            pass
        time.sleep(3.0 * (attempt + 1))
    if not d or d.get("code") != 0:
        raise RuntimeError(f"bili code={None if not d else d.get('code')}")
    res = (d.get("data") or {}).get("result") or []
    best, best_t, plays = 0, "", []
    for v in res:
        title = re.sub(r"<[^>]+>", "", v.get("title", "") or "")
        p = int(v.get("play") or 0)
        plays.append(p)
        w = 1.0
        if keyword not in title:
            w = 0.2                                   # 标题不含歌名 -> 多半无关
        if re.search(r"(合集|串烧|大全|精选|连播|催眠|纯音乐)", title):
            w *= 0.15                                 # 合集/催眠音: 播放量不属于该曲
        score = p * w
        if score > best:
            best, best_t = int(score), title
    med = int(statistics.median(plays)) if plays else 0
    return best, len(res), best_t, med


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    start = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    all_dirs = sorted(glob.glob("images-prep/**/001.jpg", recursive=True))
    # 每目录取最大 jpg(谱页), 与 batch_transcribe 的 pick_page 一致
    scores = all_dirs[start:start + n]
    os.makedirs("rank-out", exist_ok=True)
    print(f"排序区间 [{start}, {start+n})  共 {len(scores)} 张", flush=True)
    out = []
    for i, img in enumerate(scores):
        name = os.path.basename(os.path.dirname(img))
        q = clean_song(name)
        best = hits = med = 0; bt = ""
        if q:
            try:
                best, hits, bt, med = bili_stats(q)
            except Exception as ex:
                print(f"[{i+1}/{len(scores)}] 查询失败 {type(ex).__name__}: {q}", flush=True)
        r = {"name": name, "img": img, "query": q, "play": best, "hits": hits,
             "median": med, "top_title": bt, "hot": best}
        out.append(r)
        print(f"[{i+1}/{len(scores)}] play={best:>9} hits={hits:3d} {q[:20]:20s} | {bt[:36]}", flush=True)
        time.sleep(1.6)
    out.sort(key=lambda x: x["hot"], reverse=True)
    out_path = f"rank-out/ranked_{start}_{start + len(out)}.jsonl"
    with open(out_path, "w", encoding="utf-8") as f:
        for r in out:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"\n已写 {out_path}")
    print("\n=== Top 30 最可能被搜索 ===")
    for r in out[:30]:
        print(f"  play={r['play']:>9} {r['query'][:22]:22s} | {r['top_title'][:40]}")


if __name__ == "__main__":
    main()
