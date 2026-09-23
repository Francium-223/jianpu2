# -*- coding: utf-8 -*-
"""生成第二轮扩库的歌手页名单 -> train-work/artist_pages2.txt

URL 规律(jianpu.cn): http://www.jianpu.cn/g/<拼音前2字母>/<全拼>.htm
第一轮已经爬过 31 位(邓丽君/张学友/刘德华/周华健/五月天/林俊杰/蔡依林/孙燕姿/BEYOND…),
这份补**没爬过的华语歌手**(用户方向: 华流金曲/国语流行/草原民歌/怀旧)。

用法: py -3.13 tools/artist_list2.py
"""
import os
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# (中文名, 全拼)  —— 拼音手写, 免得引 pypinyin 依赖
ARTISTS = [
    ("周杰伦", "zhoujielun"), ("王菲", "wangfei"), ("陈奕迅", "chenyixun"),
    ("那英", "naying"), ("刀郎", "daolang"), ("腾格尔", "tenggeer"),
    ("韩红", "hanhong"), ("汪峰", "wangfeng"), ("许巍", "xuwei"),
    ("朴树", "pushu"), ("凤凰传奇", "fenghuangchuanqi"), ("邓紫棋", "dengziqi"),
    ("薛之谦", "xuezhiqian"), ("李荣浩", "lironghao"), ("毛不易", "maobuyi"),
    ("汪苏泷", "wangsulong"), ("张惠妹", "zhanghuimei"), ("梁静茹", "liangjingru"),
    ("刘若英", "liuruoying"), ("莫文蔚", "mowenwei"), ("任贤齐", "renxianqi"),
    ("张信哲", "zhangxinzhe"), ("周传雄", "zhouchuanxiong"), ("费玉清", "feiyuqing"),
    ("蔡琴", "caiqin"), ("李宗盛", "lizongsheng"), ("罗大佑", "luodayou"),
    ("齐秦", "qiqin"), ("张雨生", "zhangyusheng"), ("辛晓琪", "xinxiaoqi"),
    ("许美静", "xumeijing"), ("韩磊", "hanlei"), ("刘欢", "liuhuan"),
    ("田震", "tianzhen"), ("降央卓玛", "jiangyangzhuoma"), ("乌兰图雅", "wulantuya"),
    ("卓依婷", "zhuoyiting"), ("高胜美", "gaoshengmei"), ("潘美辰", "panmeichen"),
    ("陈淑桦", "chenshuhua"), ("姜育恒", "jiangyuheng"), ("童安格", "tongange"),
    ("齐豫", "qiyu"), ("孟庭苇", "mengtingwei"), ("张明敏", "zhangmingmin"),
    ("蒋大为", "jiangdawei"), ("李谷一", "liguyi"), ("苏小明", "suxiaoming"),
    ("董文华", "dongwenhua"), ("阎维文", "yanweiwen"),
]

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "Chrome/120.0.0.0 Safari/537.36")
ok = []
for name, py in ARTISTS:
    url = f"http://www.jianpu.cn/g/{py[:2]}/{py}.htm"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=20) as f:
            h = f.read()
        good = len(h) > 5000
    except Exception:
        good = False
    print(f"  {'✓' if good else '✗'} {name:<10} {url}  ({len(h) if 'h' in dir() else 0} 字节)")
    if good:
        ok.append((name, url))
    import time
    time.sleep(0.3)

with open("train-work/artist_pages2.txt", "w", encoding="utf-8") as f:
    for name, url in ok:
        f.write(f"{name}\t{url}\n")
print(f"\n可用歌手页 {len(ok)}/{len(ARTISTS)} -> train-work/artist_pages2.txt")
