# -*- coding: utf-8 -*-
"""按曲名查 MusicBrainz -> MBID。

MusicBrainz Web Service (ws/2):
  https://musicbrainz.org/ws/2/work/?query=<title>&fmt=json&limit=N
要求 User-Agent 标识; 限流约 1 请求/秒。

用法:
  py -3.13 tools/mbid_lookup.py "曲名" [work|recording]
"""
import sys, json, time, urllib.parse, urllib.request

UA = "jianpu2-transcriber/0.1 ( https://example.org/jianpu2 )"
API = "https://musicbrainz.org/ws/2/{kind}/?query={q}&fmt=json&limit={n}"


def search(title, kind="work", limit=5, retries=3):
    """返回 [(mbid, title, score), ...]，失败抛异常。"""
    url = API.format(kind=kind, q=urllib.parse.quote(title), n=limit)
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA,
                                                      "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.load(r)
            items = d.get(kind + "s", []) or []
            out = []
            for it in items:
                out.append((it.get("id"), it.get("title", ""), it.get("score")))
            return out
        except Exception as ex:
            if attempt == retries - 1:
                raise
            time.sleep(1.5 * (attempt + 1))
    return []


def best_mbid(title, kind="work"):
    """取最匹配的一个 MBID（score 最高）。retries=1: 限流时快速失败, 好让调用方转去查 Wikidata。"""
    hits = search(title, kind=kind, limit=5, retries=1)
    if not hits:
        return None, []
    hits = sorted(hits, key=lambda x: int(x[2] or 0), reverse=True)
    return hits[0][0], hits


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    title = sys.argv[1]
    kind = sys.argv[2] if len(sys.argv) > 2 else "work"
    mbid, hits = best_mbid(title, kind)
    print(f"查询: {title}  (kind={kind})")
    for h in hits:
        mark = " <== 采用" if h[0] == mbid else ""
        print(f"  {h[0]}  score={h[2]}  {h[1]}{mark}")
    if not mbid:
        print("未找到")
