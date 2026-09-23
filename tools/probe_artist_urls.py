# -*- coding: utf-8 -*-
"""测: jianpu.cn 的歌手页 URL 规律能不能用来"按歌手扩库"。"""
import re
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "Chrome/120.0.0.0 Safari/537.36")
for u in ("http://www.jianpu.cn/g/wa/wangfei.htm",
          "http://www.jianpu.cn/g/zh/zhoujielun.htm",
          "http://www.jianpu.cn/g/na/naying.htm",
          "http://www.jianpu.cn/g/da/daolang.htm",
          "http://www.jianpu.cn/g/te/tenggeer.htm"):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=20) as f:
            h = f.read().decode("utf-8", "replace")
        n = len(set(re.findall(r'href="(/[a-z]+/\d+\.html)"', h)))
        title = re.search(r"<title>(.*?)</title>", h, re.S)
        print(f"{u:<48} 页长 {len(h):>6}  曲谱链接 {n:>3}  标题 {(title.group(1).strip()[:30] if title else '?')}")
    except Exception as e:
        print(f"{u:<48} 失败 {type(e).__name__} {e}")
