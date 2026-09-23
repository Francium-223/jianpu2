# -*- coding: utf-8 -*-
"""按播放量列出热度最高的歌, 并修 mojibake。"""
import glob, json, os, re, sys
sys.path.insert(0, "tools"); sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def fix(s):
    try:
        d = s.encode("latin-1").decode("utf-8")
        if d and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in d):
            return d
    except Exception:
        pass
    return s

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
    t = fix(d)
    t = re.sub(r"__(qupu123|jianpujia|jianpucn)-\d+$", "", t)
    t = re.sub(r"[（(].*$", "", t)
    t = re.sub(r"^(简谱|钢琴|吉他)", "", t)
    t = re.sub(r"(简谱|钢琴谱|吉他谱|正谱|双谱|歌词)$", "", t)
    t = re.sub(r"_+", " ", t).strip()[:34]
    out.append((r.get("play", 0), t))
print(f"共 {len(out)} 首; 播放量前 70:")
for i, (p, t) in enumerate(out[:70], 1):
    print(f"{i:3d}. {p:>9,}  {t}")
