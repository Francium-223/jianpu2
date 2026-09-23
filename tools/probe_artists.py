# -*- coding: utf-8 -*-
"""批量试探 jianpu.cn 的歌手页 URL, 找出真实存在的, 为"大牌整页爬"做准备。

网站模式(实测周杰伦): /g/<拼音前2字母>/<全拼>.htm
但站内拼写不一定标准(实测陈奕迅是 chenzuoxun, 不是 chenyixun), 所以要多试几个变体。
用法: py tools/probe_artists.py
"""
import os, re, sys, urllib.request
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

# 名字 -> 候选拼音(第一个是标准拼音, 后面是可能的站内写法)
ARTISTS = {
    "邓丽君": ["denglijun", "tenglichun"],
    "王菲": ["wangfei"],
    "张学友": ["zhangxueyou"],
    "刘德华": ["liudehua"],
    "周华健": ["zhouhuajian"],
    "五月天": ["wuyuetian"],
    "林俊杰": ["linjunjie"],
    "蔡依林": ["caiyilin"],
    "孙燕姿": ["sunyanzi"],
    "邓紫棋": ["dengziqi", "gemo"],
    "费玉清": ["feiyuqing"],
    "韩红": ["hanhong"],
    "刘欢": ["liuhuan"],
    "宋祖英": ["songzuying"],
    "李谷一": ["liguyi"],
    "蒋大为": ["jiangdawei"],
    "毛阿敏": ["maomin"],
    "腾格尔": ["tenggeer", "tengger"],
    "阎维文": ["yanweiwen"],
    "张也": ["zhangye"],
    "降央卓玛": ["jiangyangzhuoma"],
    "乌兰图雅": ["wulantoya"],
    "凤凰传奇": ["fenghuangchuanqi"],
    "汪峰": ["wangfeng"],
    "许巍": ["xuwei"],
    "朴树": ["pushu"],
    "李健": ["lijian"],
    "毛不易": ["maobuyi"],
    "周深": ["zhoushen"],
    "华晨宇": ["huachenyu"],
    "薛之谦": ["xuezhiqian"],
    "张靓颖": ["zhangliangying", "zhangzuoying"],
    "twins": ["twins"],
    "beyond": ["beyond"],
}


def probe(pinyin):
    url = f"http://www.jianpu.cn/g/{pinyin[:2]}/{pinyin}.htm"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=15) as r:
            html = r.read().decode("gbk", errors="replace")
        n = len(re.findall(r"href='(/pu/\d+/\d+\.htm)'", html))
        if n >= 5:
            return url, n
    except Exception:
        pass
    return None, 0


found = []
for name, cands in ARTISTS.items():
    for py in cands:
        url, n = probe(py)
        if url:
            print(f"  ✓ {name:8s} {url}  {n} 首")
            found.append((name, url, n))
            break
    else:
        print(f"  ✗ {name:8s} (试过 {'/'.join(cands)})")

with open("train-work/artist_pages.txt", "w", encoding="utf-8") as g:
    for name, url, n in found:
        g.write(f"{name}\t{url}\t{n}\n")
print(f"\n找到 {len(found)}/{len(ARTISTS)} 个歌手页 -> train-work/artist_pages.txt")
