# -*- coding: utf-8 -*-
"""按 MusicBrainz 热度给谱图排序: 优先转写"最可能被搜索"的曲子。

热度指标:
  1) 该曲在 MusicBrainz 能否找到 work
  2) 该 work 的 recording 数量(被翻录/发行越多 = 越知名)
  3) 搜索匹配分(score)
用法: py -3.13 tools/rank_by_mb.py [数量]   -> 输出 rank-out/ranked.jsonl + 打印 Top 30
"""
import os, sys, glob, re, json, time, urllib.parse, urllib.request
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from to_jianpu_db import title_of

UA = "jianpu2-transcriber/0.1 ( https://example.org/jianpu2 )"
WS = "https://musicbrainz.org/ws/2/"


def _get(path, params):
    url = WS + path + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)


def clean_query(name):
    t = title_of(name)
    t = re.sub(r"^\[[^\]]{1,3}\]", "", t)
    t = re.split(r"[_\[]", t)[0]
    segs = re.findall(r"[A-Za-z][A-Za-z' ]{2,}|[\u4e00-\u9fff]{2,}", t)
    return (segs[0] if segs else t)[:60].strip()


def lookup(name):
    """返回 {q, mbid, mb_title, score, recordings}"""
    q = clean_query(name)
    res = {"q": q, "mbid": "", "mb_title": "", "score": 0, "recordings": 0}
    if not q:
        return res
    try:
        d = _get("work/", {"query": q, "fmt": "json", "limit": 3})
    except Exception:
        return res
    works = d.get("works", [])
    if not works:
        return res
    works = sorted(works, key=lambda w: int(w.get("score") or 0), reverse=True)
    w = works[0]
    res["mbid"] = w.get("id", "")
    res["mb_title"] = w.get("title", "")
    res["score"] = int(w.get("score") or 0)
    time.sleep(1.1)
    if res["mbid"]:
        try:
            d2 = _get("work/" + res["mbid"], {"inc": "recording-rels", "fmt": "json"})
            res["recordings"] = len(d2.get("relations", []) or [])
        except Exception:
            pass
    return res


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    scores = sorted(glob.glob("images-prep/**/001.jpg", recursive=True))[:n]
    os.makedirs("rank-out", exist_ok=True)
    out = []
    for i, img in enumerate(scores):
        name = os.path.basename(os.path.dirname(img))
        r = lookup(name)
        r["name"] = name
        r["img"] = img
        r["hot"] = r["recordings"] * 10 + r["score"]      # 热度: 录音数为主, 匹配分为辅
        out.append(r)
        print(f"[{i+1}/{len(scores)}] rec={r['recordings']:3d} score={r['score']:3d} "
              f"{r['mb_title'][:34]:34s} <- {name[:34]}", flush=True)
        time.sleep(1.1)
    out.sort(key=lambda x: x["hot"], reverse=True)
    with open("rank-out/ranked.jsonl", "w", encoding="utf-8") as f:
        for r in out:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"\n=== Top 25 最可能被搜索 ===")
    for r in out[:25]:
        print(f"  rec={r['recordings']:3d} score={r['score']:3d} {r['mb_title'][:40]}")


if __name__ == "__main__":
    main()
