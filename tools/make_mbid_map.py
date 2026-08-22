# -*- coding: utf-8 -*-
"""从各目录 mbid_review.csv 生成 MBID 映射建议:
- mbid_map_suggested.json: 可直接给 convert.py --mbid-file 用
  (候选标题与曲名规范化完全一致且 score 足够高才建议)
- mbid_manual_review.csv:  所有未填歌曲 + 前3候选, 供人工挑对

用法: python tools/make_mbid_map.py
"""
import csv
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

DIRS = ["scores-7b", "scores-7b-2", "scores-7b-3", "scores-7b-4",
        "scores-7b-5", "scores-7b-pucn", "scores-7b-pujia"]

MIN_SCORE = 70


def norm(s):
    # 去空白/小写; 繁→简单向映射常用字, 提高命中
    t = re.sub(r"\s+", "", (s or "").lower())
    for f, t2 in (("難", "难"), ("銀", "银"), ("臨", "临"), ("閃", "闪"), ("憫", "悯"),
                  ("農", "农"), ("燈", "灯"), ("遊", "游"), ("愛", "爱"), ("樂", "乐"),
                  ("煙", "烟"), ("淒", "凄"), ("迷", "迷"), ("舊", "旧"), ("雲", "云")):
        t = t.replace(f, t2)
    return t


def match_grade(cand_title, title):
    """'exact' 完全一致 / 'contains' 一方包含另一方 / None 无关。"""
    a, b = norm(cand_title), norm(title)
    if not a or not b:
        return None
    if a == b:
        return "exact"
    if len(b) >= 2 and b in a:
        return "contains"
    if len(a) >= 2 and a in b:
        return "contains"
    return None


def main():
    suggested, review_rows = {}, {}
    for d in DIRS:
        csv_path = os.path.join(d, "mbid_review.csv")
        if not os.path.exists(csv_path):
            continue
        with open(csv_path, encoding="utf-8-sig") as f:
            for row in csv.DictReader(f):
                title = (row.get("title") or "").strip()
                mbid = (row.get("mbid") or "").strip()
                matched = row.get("matched") or ""
                pairs = []
                try:
                    pairs = json.loads(matched)
                except Exception:
                    pass
                if not isinstance(pairs, list):
                    pairs = []
                # 规范化成 [(kind, cand), ...]
                cands = []
                for p in pairs:
                    if isinstance(p, list) and len(p) == 2 and isinstance(p[1], dict):
                        cands.append((p[0], p[1]))
                    elif isinstance(p, dict):
                        cands.append(("work", p))
                if mbid:
                    review_rows.setdefault(title, [d, title, row.get("artist", ""),
                                                   mbid, row.get("confidence", ""), "", "已填"])
                    continue
                if title in suggested:
                    continue
                best, best_grade = None, None
                song_artist = row.get("artist", "") or ""
                for kind, c in cands:
                    g = match_grade(c.get("title"), title)
                    if not g or c.get("score", 0) < MIN_SCORE:
                        continue
                    # 歌手佐证: 候选歌手与爬虫歌手规范化一致 → contains 也够格建议
                    a_ok = False
                    ca = c.get("artists") or []
                    if song_artist:
                        a_ok = any(norm(x) and (norm(song_artist) in norm(x) or norm(x) in norm(song_artist))
                                   for x in ca)
                    if best is None or (g, a_ok, c["score"]) > (best_grade, best_a_ok, best["score"]):
                        best, best_grade = c, g
                        best_a_ok = a_ok
                if best:
                    if best_grade == "exact" or (best_grade == "contains" and best_a_ok):
                        suggested[title] = {"mbid": best["id"], "type": "work"}
                        review_rows.setdefault(title, [d, title, row.get("artist", ""),
                                                       best["id"], f"suggest-{best_grade}({best['score']})",
                                                       best.get("title", ""), "建议"])
                    else:
                        review_rows.setdefault(title, [d, title, row.get("artist", ""), "",
                                                       f"near({best_grade},{best['score']})",
                                                       best.get("title", ""), "待人工"])
                else:
                    top = " | ".join(f"{c.get('title','')}({c.get('score','?')})"
                                     for _, c in cands[:3]) or "无候选"
                    review_rows.setdefault(title, [d, title, row.get("artist", ""), "",
                                                   "", top, "待人工"])
    with open("mbid_map_suggested.json", "w", encoding="utf-8") as f:
        json.dump(suggested, f, ensure_ascii=False, indent=1)
    with open("mbid_manual_review.csv", "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["dir", "title", "artist", "mbid", "confidence", "candidates", "status"])
        w.writerows(review_rows.values())
    n_sug = len(suggested)
    n_manual = sum(1 for r in review_rows.values() if r[6] == "待人工")
    print(f"建议映射: {n_sug} 首 → mbid_map_suggested.json")
    print(f"待人工复核: {n_manual} 首 → mbid_manual_review.csv")
    print("用法: python convert.py --out scores-xxx --mbid-only --mbid-file mbid_map_suggested.json")


if __name__ == "__main__":
    main()
