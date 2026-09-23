# -*- coding: utf-8 -*-
"""知名歌曲清单: A) 按播放量前 N; B) 从 1408 个 scores 标题里挑经典。"""
import glob, json, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def fix(s):
    """返回 (清洗后的标题, 是否仍残留乱码字符)。"""
    for errors in ("strict", "replace"):
        try:
            d = s.encode("latin-1", errors="ignore").decode("utf-8", errors=errors)
            if d and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in d):
                return d, ("\ufffd" in d)
        except Exception:
            continue
    # 解不出来: 判断是否本来就是 mojibake
    return s, bool(re.search(r"[\u00c0-\u00ff]{2,}", s))

rows = []
for rf in sorted(glob.glob("rank-out/ranked*.jsonl")):
    for l in open(rf, encoding="utf-8"):
        try:
            rows.append(json.loads(l))
        except Exception:
            pass
rows.sort(key=lambda r: r.get("play", 0), reverse=True)
seen, out = set(), []
for r in rows:
    d = os.path.basename(os.path.dirname(r["img"]))
    if d in seen:
        continue
    seen.add(d)
    t, ok = fix(d)
    t = re.sub(r"__(qupu123|jianpujia|jianpucn)-\d+$", "", t)
    t = re.sub(r"[（(].*$", "", t)
    t = re.sub(r"(简谱|钢琴谱|吉他谱|正谱|双谱|歌词)$", "", t)
    t = re.sub(r"^(简谱|钢琴|吉他)", "", t)
    t = re.sub(r"[_\s]+", " ", t).strip()
    out.append((r.get("play", 0), t[:30], ok))

print("### A) 播放量前 45（热度≈知名度）")
for i, (p, t, ok) in enumerate(out[:45], 1):
    flag = "" if ok else "  [标题乱码]"
    print(f"{i:3d}. {p:>9,}  {t}{flag}")

titles = sorted(os.path.basename(f)[:-4] for f in glob.glob("jianpu-db-out/scores/*.txt"))
bad = sum(1 for t in titles if re.search(r"[Â-ÿ]{2,}", t))
print(f"\n### B) scores 共 {len(titles)} 个（其中标题仍乱码 {bad} 个）")

KW = ["两只老虎","小星星","卖报歌","上学歌","小燕子","让我们荡起双桨","世上只有妈妈好","采蘑菇的小姑娘",
      "数鸭子","拔萝卜","丢手绢","一分钱","小螺号","兰花草","蜗牛与黄鹂鸟","铃儿响叮当","生日快乐","新年好",
      "春天在哪里","小毛驴","读书郎","娃哈哈","歌声与微笑","虫儿飞","白龙马","小红花","雪绒花","友谊",
      "茉莉花","义勇军进行曲","半个月亮爬上来","保卫黄河","女儿情","上海滩","告白气球","光年之外",
      "夜空中最亮的星","刚好遇见你","寂寞沙洲冷","三国恋","乌兰巴托的夜","偏偏喜欢你","凤凰花开的路口",
      "容易受伤的女人","Yesterday","Because of You","Let It Go","Lemon","小跳蛙","童年","同桌的你",
      "月亮代表我的心","甜蜜蜜","朋友","后来","童话","成都","稻香","隐形的翅膀","孤勇者","海阔天空"]
seen2, hits = set(), []
for kw in KW:
    for t in titles:
        if kw.lower() in t.lower() and t not in seen2:
            seen2.add(t); hits.append(t)
print(f"\n命中的经典/知名: {len(hits)}")
for t in hits:
    print("   ", t[:44])
