# -*- coding: utf-8 -*-
"""把第二轮曲名清洗(train-work/title_fix2.tsv)合并进 train-work/title_clean.tsv。

为什么要人工过一遍: 这批名字里很多带 `_` —— 那是爬虫**丢字节**留下的记号
(如 `我们是_产主义接班人` = 我们是共产主义接班人), 模型有时能猜回、有时直接把尾字砍掉
(`草原_怀` -> `草原`, 于是和别的《草原》撞名) ✗。所以:
  * 先取模型结果, 再套一张**明确的修正表**(下面是逐条看过原文后定的)
  * 合并且只覆盖"有改动"的行, 其余保持原样
产物: 更新 train-work/title_clean.tsv(重建 scores 时会自动生效)
用法: py -3.13 tools/apply_title_fix2.py [--dry]
"""
import csv
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DRY = "--dry" in sys.argv
FIX2 = "train-work/title_fix2.tsv"
CLEAN = "train-work/title_clean.tsv"

# 逐条核对原文后定的修正(键 = 原始名, 值 = 人定的正确歌名)
OVERRIDE = {
    "有没有钢琴简谱_薛之谦演唱": "有没有",
    "不懂钢琴简谱_林俊杰演唱": "不懂",
    "合拍钢琴简谱_许嵩演唱": "合拍",
    "又是一年秋天草原丁喜萨斯原创曲简谱_草原龙_演唱_马正寿": "又是一年秋天",
    "我要_电影_驴得水_主题曲电影_驴得水_主题曲简谱_老狼演唱": "我要你",
    "我们是_产主义接班人简谱(歌词)_儿歌_小弩曲谱-简谱": "我们是共产主义接班人",
    "我们是_产主义接班人简谱(歌词)_儿歌_暖儿曲谱-简谱": "我们是共产主义接班人",
    "月牙五更经_民歌100首简谱_徐志列演唱_吉林民歌_刘_义_": "月牙五更",
    "民族声乐考级歌曲：康定_歌简谱_民歌演唱_王wzh制作曲谱-": "康定情歌",
    "燕子归来草原丁喜萨_斯原创曲简谱_草原丁喜演唱_草原大哈": "燕子归来",
    "燕子归来草原丁喜萨斯原创曲简谱_草原大哈演唱_草原大哈_": "燕子归来",
    "草原_怀简谱_草原幺妹演唱_草原大哈_草原丁喜词曲-简谱": "草原情怀",
    "草原_歌知音草原恋曲系列之四简谱-简谱": "草原恋歌",
    "草原_歌草原姑娘唱简谱_杨子歌曲_赵伟zhaowei上_-简谱": "草原恋歌",
    "草原_名河草原歌曲100首简谱_德德玛演唱_王然_呼_吉夫词": "草原名河",
    "草原_草原风简谱-简谱": "草原草原风",
    "咖啡在等一个人等一个人咖啡电影主题曲_老板娘主题曲EPHK精": "咖啡在等一个人",
    "缺口等一个人咖啡电影主题曲_阿拓主题曲EPHK精准版简谱_庾": "缺口",
    "等一个人等一个人咖啡电影主题曲_思萤主题曲EPHK精准版简谱": "等一个人",
    "阿里山的姑娘_民歌100首简谱-简谱": "阿里山的姑娘",
    "贝斯谱P_Q": "贝斯谱",
    "26_铺开一片蔚蓝（双谱）": "铺开一片蔚蓝",
    "Blue_Berry_Hill_鸟饭树山（蓝莓山）": "Blue Berry Hill 鸟饭树山",
    "dance_monkey（跳舞的猴子）": "dance monkey",
    "（改编歌曲）": "改编歌曲",
    "紫藤花（选自歌剧《伤逝》）": "紫藤花",
    "又弹起心爱的土琵琶（刘德华）": "又弹起心爱的土琵琶",
    "黑眼睛金波词杨春华曲、儿歌黑眼睛金波词_杨春华曲、儿歌": "黑眼睛",
    "草原海陈世_词_艺军曲草原海陈世_词__艺军曲简谱-简谱": "草原海",
    "草原再等_草原丁喜萨斯原创曲简谱_马正寿演唱_马正寿_草": "草原再等",
    "草原，我的_乡简谱_电视片_草原风": "草原，我的故乡",
    "草原，我思恋的_乡简谱_午耶词_齐峰曲-简谱": "草原，我思恋的故乡",
    "草原，我灵魂回归的天_简谱__晓宏词_吴雄曲-简谱": "草原，我灵魂回归的天堂",
    "草原，我眷恋的_乡简谱__建中词_严_和曲-简谱": "草原，我眷恋的故乡",
    "草原，我眷恋的_乡简谱__建中词_戴阿鹏曲-简谱": "草原，我眷恋的故乡",
    "草原，我眷恋的_乡简谱__建中词_李延烈曲-简谱": "草原，我眷恋的故乡",
    "草原，我眷恋的_乡简谱__建中词_李海明曲-简谱": "草原，我眷恋的故乡",
    "草原，我眷恋的_乡简谱__建中词_粱恒杰曲-简谱": "草原，我眷恋的故乡",
    "草原，我眷恋的_乡简谱__建中词_逸夫曲-简谱": "草原，我眷恋的故乡",
}

rows = {}
with open(FIX2, encoding="utf-8") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        rows[r["目录名"]] = r

final = {}
if os.path.exists(CLEAN):
    with open(CLEAN, encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            final[r["目录名"]] = r

merged, over, skipped = 0, 0, 0
for full, r in rows.items():
    new = OVERRIDE.get(r["原始名"], r["模型曲名"])
    if new in ("", "?"):
        skipped += 1
        continue
    if new == r["原始名"]:
        continue
    used_override = r["原始名"] in OVERRIDE
    final[full] = {"目录名": full, "原始名": r["原始名"], "模型曲名": new,
                   "有变化": "1", "原文输出": "override" if used_override else r.get("原文输出", "")}
    merged += 1
    over += int(used_override)

print(f"合并 {merged} 条(其中人工修正 {over} 条), 跳过 {skipped} 条")
if DRY:
    print("(dry run, 没写文件)")
    sys.exit(0)
with open(CLEAN, "w", encoding="utf-8") as f:
    f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
    for k, r in final.items():
        f.write("\t".join(str(r.get(c, "")).replace("\t", " ") for c in
                          ("目录名", "原始名", "模型曲名", "有变化", "原文输出")) + "\n")
print(f"-> {CLEAN} 现在 {len(final)} 条")
