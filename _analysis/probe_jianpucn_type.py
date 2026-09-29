# -*- coding: utf-8 -*-
"""探针: jianpu.cn 分类列表页里"类型"(简谱/吉他谱/钢琴谱)现在写在哪。

crawl_jianpucn2.py 靠 `条目文本 starts with "[简谱]"` 过滤, 2026-09-29 实测收集到 **0** 条
(站点改版, 括号里现在放的是歌手名)。本探针只读, 打印原始条目 HTML 片段找新位置。
用法: py -3.13 _analysis/probe_jianpucn_type.py [分类=sizigepu]
"""
import re
import sys
import urllib.request

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
CAT = sys.argv[1] if len(sys.argv) > 1 else "sizigepu"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")


for page in ("", "/2.htm"):
    url = f"http://www.jianpu.cn/{CAT}{page}"
    try:
        h = fetch(url)
    except Exception as e:
        print(f"[{url}] 取不到: {e}")
        continue
    print(f"===== {url}  长度 {len(h)}")
    ms = list(re.finditer(r"href='(/pu/\d+/\d+\.htm)'", h))
    print(f"  条目链接 {len(ms)} 个")
    for m in ms[:6]:
        a, b = max(0, m.start() - 130), m.end() + 130
        print("   ----")
        print("   " + h[a:b].replace("\r", " ").replace("\n", " ")[:300])
    # 找所有括号标签的形态
    tags = re.findall(r"\[([^\]]{1,8})\]", h)
    print(f"  方括号标签统计: {sorted(set(tags))[:20]}")
    txt = re.findall(r">([^<>]{2,40})</a>", h)
    print(f"  示例链接文本: {txt[:6]}")
