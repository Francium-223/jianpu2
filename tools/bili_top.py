# -*- coding: utf-8 -*-
"""拉 B站音乐区排行榜 Top N, 提取视频标题(作为热门曲目线索)。

接口: /x/web-interface/ranking/v2?rid=3  (rid=3 为音乐区)
用法: py -3.13 tools/bili_top.py [数量] [rid]
输出: hit-out/bili_top.jsonl  + 打印歌名线索
"""
import json, os, re, sys, time, uuid, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

HDR = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/122.0 Safari/537.36",
    "Referer": "https://www.bilibili.com/",
    "Accept": "application/json, text/plain, */*",
    "Cookie": "buvid3=%s-infoc; b_nut=1700000000" % uuid.uuid4(),
}


def ranking(rid=3, pages=1):
    """取排行榜; 每页 100 条。"""
    out = []
    for p in range(1, pages + 1):
        url = (f"https://api.bilibili.com/x/web-interface/ranking/v2"
               f"?rid={rid}&type=all&pn={p}")
        d = None
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, headers=HDR)
                with urllib.request.urlopen(req, timeout=20) as r:
                    d = json.load(r)
                if d.get("code") == 0:
                    break
            except Exception:
                pass
            time.sleep(2.0 * (attempt + 1))
        if not d or d.get("code") != 0:
            print(f"  第 {p} 页失败 code={None if not d else d.get('code')}", flush=True)
            continue
        for v in (d.get("data") or {}).get("list", []) or []:
            out.append({
                "title": re.sub(r"<[^>]+>", "", v.get("title", "")),
                "view": (v.get("stat") or {}).get("view", 0),
                "up": (v.get("owner") or {}).get("name", ""),
                "bvid": v.get("bvid", ""),
            })
        time.sleep(1.2)
    return out


def main():
    pages = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    rid = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    os.makedirs("hit-out", exist_ok=True)
    rows = ranking(rid, pages)
    print(f"取到 {len(rows)} 条 (rid={rid}, {pages} 页)")
    with open("hit-out/bili_top.jsonl", "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    rows.sort(key=lambda r: r["view"], reverse=True)
    print("\n=== 播放量 Top 30 ===")
    for r in rows[:30]:
        print(f"  {r['view']:>10,}  {r['title'][:52]}  @{r['up'][:16]}")


if __name__ == "__main__":
    main()
