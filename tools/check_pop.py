# -*- coding: utf-8 -*-
"""批量查: 常见华语流行/经典歌曲在不在库里(修 mojibake 后匹配)。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def fix(s):
    try:
        d = s.encode("latin-1").decode("utf-8")
        if d and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in d):
            return d
    except Exception:
        pass
    return s

scores = [os.path.basename(f)[:-4] for f in glob.glob("jianpu-db-out/scores/*.txt")]
allnames = scores + [fix(os.path.basename(p)) for p in glob.glob("images-prep/*/*")]

LIST = {
    "周杰伦": ["晴天", "稻香", "告白气球", "七里香", "青花瓷", "简单爱", "夜曲", "听妈妈的话", "菊花台",
            "龙卷风", "屋顶", "搁浅", "明明就", "算什么男人", "不能说的秘密", "蒲公英的约定", "珊瑚海"],
    "陈奕迅": ["富士山下", "十年", "浮夸", "红玫瑰", "单车", "K歌之王", "好久不见", "你的背包", "陀飞轮",
            "爱情转移", "白玫瑰", "陪你度过漫长岁月"],
    "邓紫棋": ["光年之外", "泡沫", "句号", "画", "多远都要在一起"],
    "五月天": ["温柔", "倔强", "突然好想你", "知足", "干杯"],
    "李荣浩": ["年少有为", "模特", "老街", "麻雀"],
    "毛不易": ["消愁", "像我这样的人", "一荤一素"],
    "薛之谦": ["演员", "丑八怪", "认真的雪"],
    "许嵩": ["有何不可", "断桥残雪", "庐州月"],
    "经典老歌": ["月亮代表我的心", "甜蜜蜜", "朋友", "童年", "同桌的你", "隐形的翅膀", "小幸运", "后来",
             "童话", "海阔天空", "光辉岁月", "真的爱你", "红日", "上海滩", "铁血丹心", "沧海一声笑",
             "男儿当自强", "大约在冬季", "一剪梅", "军港之夜", "乡恋", "我的中国心", "龙的传人"],
    "近年热歌": ["孤勇者", "起风了", "少年", "可可托海的牧羊人", "听闻远方有你", "早安隆回", "一路生花",
             "世界这么大还是遇见你", "桥边姑娘", "点歌的人", "云与海", "影子说"],
}
tot = 0
for cat, kws in LIST.items():
    hit = []
    for kw in kws:
        for n in allnames:
            if kw in n:
                hit.append(kw); break
    tot += len(hit)
    print(f"\n### {cat}  ({len(hit)}/{len(kws)})")
    print("   有:", "、".join(hit) if hit else "（无）")
    miss = [k for k in kws if k not in hit]
    if miss:
        print("   无:", "、".join(miss))
print(f"\n合计命中 {tot} 首")
