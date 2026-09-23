# -*- coding: utf-8 -*-
"""抓 B 站"音乐区"排行榜(rid=3), 按**播放量**重排, 存成 markdown + json。
用法: py -3.13 tools/bili_music_top.py [rid] [输出前缀]
说明: 官方排行榜本身是"综合热度"排序, 所以这里按 stat.view 重排 —— 用户问的是播放量 top。
     接口要浏览器的 UA + 先拿一次首页 cookie(buvid3), 否则容易 -412 风控。
"""
import json
import os
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

RID = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].isdigit() else "3"
PREFIX = sys.argv[2] if len(sys.argv) > 2 else "train-work/bili_music_top"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

_jar = {}


def _cookie_header():
    return "; ".join(f"{k}={v}" for k, v in _jar.items())


def get(url, api=False):
    hdr = {"User-Agent": UA, "Referer": "https://www.bilibili.com/",
           "Accept": "application/json, text/plain, */*"}
    if _jar:
        hdr["Cookie"] = _cookie_header()
    req = urllib.request.Request(url, headers=hdr)
    with urllib.request.urlopen(req, timeout=30) as r:
        for v in (r.headers.get_all("Set-Cookie") or []):
            # get_all 返回的是 "k=v; Path=/; ..." 字符串列表, **不能 for k, v in ...** 解包 ✗
            kv = v.split(";")[0]
            if "=" in kv:
                kk, vv = kv.split("=", 1)
                _jar[kk.strip()] = vv.strip()
        body = r.read()
    return json.loads(body.decode("utf-8")) if api else body


print("1) 先访问首页拿 cookie ...")
try:
    get("https://www.bilibili.com/")
    print("   cookie:", ", ".join(sorted(_jar)) or "(空)")
except Exception as e:
    print("   首页失败:", e)

url = f"https://api.bilibili.com/x/web-interface/ranking/v2?rid={RID}&type=all"
print(f"2) 拉排行榜 rid={RID} ...")
d = None
for attempt in range(3):
    try:
        d = get(url, api=True)
        if d.get("code") == 0:
            break
        print(f"   第 {attempt+1} 次 code={d.get('code')} msg={d.get('message')}")
    except Exception as e:
        print(f"   第 {attempt+1} 次异常: {e}")
    time.sleep(2.5)

if not d or d.get("code") != 0:
    print("拿不到排行榜:", d.get("code") if d else None, d.get("message") if d else "")
    sys.exit(1)

lst = (d.get("data") or {}).get("list") or []
print(f"   拿到 {len(lst)} 条")

rows = []
for i, v in enumerate(lst, 1):
    st = v.get("stat") or {}
    rows.append({
        "榜位": i,
        "标题": (v.get("title") or "").replace("\n", " "),
        "up主": (v.get("owner") or {}).get("name", ""),
        "播放量": st.get("view", 0),
        "弹幕": st.get("danmaku", 0),
        "点赞": st.get("like", 0),
        "时长秒": v.get("duration", 0),
        "发布日期": time.strftime("%Y-%m-%d", time.localtime(v["pubdate"])) if v.get("pubdate") else "",
        "分区": v.get("tname", ""),
        "BV": v.get("bvid", ""),
    })

by_view = sorted(rows, key=lambda r: -r["播放量"])

with open(f"{PREFIX}.json", "w", encoding="utf-8") as f:
    json.dump(by_view, f, ensure_ascii=False, indent=1)

lines = [f"# B 站音乐区排行榜（rid={RID}，按播放量重排）", "",
         f"抓取时间：{time.strftime('%Y-%m-%d %H:%M')}　共 {len(by_view)} 条", "",
         "| # | 播放量 | 标题 | UP主 | 时长 | 发布 | 分区 | BV |",
         "|---|---|---|---|---|---|---|---|"]
for n, r in enumerate(by_view, 1):
    dur = f"{r['时长秒']//60}:{r['时长秒']%60:02d}"
    lines.append(f"| {n} | {r['播放量']:,} | {r['标题'][:60]} | {r['up主'][:24]} | {dur} | "
                 f"{r['发布日期']} | {r['分区']} | {r['BV']} |")
with open(f"{PREFIX}.md", "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print(f"\n已存 {PREFIX}.md / {PREFIX}.json")
print("\n播放量前 20：")
for n, r in enumerate(by_view[:20], 1):
    print(f"  {n:3d}. {r['播放量']:>12,}  {r['标题'][:52]:54s} — {r['up主'][:18]}")
