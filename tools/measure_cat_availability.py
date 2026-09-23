# -*- coding: utf-8 -*-
"""量化"各类别歌曲在曲谱站的简谱可得率" —— 决定用哪个 category 做 Top100 基准。
做法: 每个类别取若干首公认代表作, 去 qupu123 搜, 数 **/tongsu/(通俗简谱)** 命中数。
      /qiyue/(器乐/钢琴) 不算 —— 那类我们既不收也转不了。
用法: py -3.13 tools/measure_cat_availability.py [每类首数]
"""
import os
import re
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 8

CATS = {
    "周杰伦": ["青花瓷", "简单爱", "七里香", "晴天", "稻香", "告白气球", "东风破", "发如雪",
             "菊花台", "双截棍", "夜曲", "龙卷风", "千里之外", "听妈妈的话", "算什么男人"],
    "凤凰传奇": ["最炫民族风", "月亮之上", "自由飞翔", "荷塘月色", "全是爱", "天蓝蓝",
              "我从草原来", "中国味道", "奢香夫人", "郎的诱惑"],
    "华语流行金曲": ["童话", "后来", "遇见", "情非得已", "丁香花", "老鼠爱大米", "隐形的翅膀",
                "过火", "心太软", "大约在冬季", "我只在乎你", "月亮代表我的心"],
    "台湾流行": ["倔强", "温柔", "突然好想你", "小幸运", "那些年", "修炼爱情", "江南",
              "一千年以后", "说好的幸福呢", "爱笑的眼睛"],
    "内地民谣摇滚": ["蓝莲花", "曾经的你", "春天里", "怒放的生命", "生如夏花", "平凡之路",
               "成都", "南方姑娘", "董小姐", "安河桥"],
    "少儿儿歌": ["小星星", "两只老虎", "世上只有妈妈好", "让我们荡起双桨", "卖报歌", "数鸭子",
             "小燕子", "一分钱", "找朋友", "丢手绢"],
    "中国民歌": ["茉莉花", "康定情歌", "敖包相会", "小河淌水", "沂蒙山小调", "在那遥远的地方",
               "龙船调", "绣荷包", "兰花花", "小白菜"],
    "红歌/革命歌曲": ["东方红", "南泥湾", "歌唱祖国", "我的祖国", "映山红", "十送红军",
                  "英雄赞歌", "浏阳河", "洪湖水浪打浪", "谁不说俺家乡好"],
    "港乐经典": ["千千阙歌", "海阔天空", "光辉岁月", "上海滩", "铁血丹心", "万水千山总是情",
              "一生何求", "红日", "喜欢你", "真的爱你"],
    "怀旧国语老歌": ["月亮代表我的心", "甜蜜蜜", "一剪梅", "恰似你的温柔", "小城故事",
                "何日君再来", "夜来香", "绿岛小夜曲", "南海姑娘", "又见炊烟"],
    "影视金曲": ["沧海一声笑", "一生所爱", "铁血丹心", "云宫迅音", "敢问路在何方",
              "上海滩", "菊花台", "暗香", "向天再借五百年", "滚滚长江东逝水"],
    "古风/国风": ["盗将行", "芒种", "赤伶", "牵丝戏", "琵琶行", "离人愁", "广寒宫",
               "风筝误", "半壶纱", "下山"],
    "网络热歌": ["孤勇者", "踏山河", "听我说谢谢你", "少年", "错位时空", "白月光与朱砂痣",
              "点歌的人", "云与海", "秒针", "人间半途"],
    "西方/外文歌": ["Yesterday", "My Heart Will Go On", "Casablanca", "Moon River",
                "Take Me to Your Heart", "Edelweiss", "Jingle Bells", "Amazing Grace"],
}


def probe(key):
    u = f"https://www.qupu123.com/Search?keys={urllib.parse.quote(key)}"
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        html = r.read().decode("utf-8", errors="replace")
    ids = set(re.findall(r'href="(/[a-z]+/[a-z0-9]*/?p\d+\.html)"', html))
    tongsu = sum(1 for i in ids if i.startswith("/tongsu/"))
    qiyue = sum(1 for i in ids if i.startswith("/qiyue/"))
    jipu = sum(1 for i in ids if i.startswith("/jipu/"))
    return tongsu, jipu, qiyue, len(ids)


print(f"每类取前 {LIMIT} 首去 qupu123 搜(通俗简谱 /tongsu 才算可用)\n")
print(f"{'类别':<14}{'有简谱的曲目':>14}{'可得率':>9}{'通俗谱总数':>11}{'器乐谱总数':>11}")
summary = []
for cat, songs in CATS.items():
    ok = tot_t = tot_q = 0
    detail = []
    for s in songs[:LIMIT]:
        try:
            t, j, q, n = probe(s)
        except Exception as e:
            detail.append(f"{s}: 查询失败({type(e).__name__})")
            continue
        if t > 0:
            ok += 1
        tot_t += t
        tot_q += q
        detail.append(f"{s}:{t}")
        time.sleep(0.5)
    n = len(songs[:LIMIT])
    rate = 100.0 * ok / n if n else 0
    summary.append((cat, ok, n, rate, tot_t, tot_q))
    print(f"{cat:<14}{ok:>8}/{n:<5}{rate:>8.0f}%{tot_t:>11}{tot_q:>11}")
    print(f"              明细(通俗谱数): {' '.join(detail)}")

print("\n按可得率排序:")
for cat, ok, n, rate, tt, tq in sorted(summary, key=lambda x: -x[3]):
    print(f"  {rate:5.0f}%  {cat:<14} {ok}/{n}   通俗谱 {tt}  器乐谱 {tq}")
