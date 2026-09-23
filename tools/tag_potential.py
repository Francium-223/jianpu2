# -*- coding: utf-8 -*-
"""凭现有信息, OCR 语料能推出多少"标签"?(只测量, 不猜)"""
import glob, io, os, re, sys
from collections import Counter
os.chdir(r"D:\Documents_D\jianpu2"); sys.stdout.reconfigure(encoding="utf-8")
FS = [f for f in glob.glob("jianpu-db-out/scores/*.txt")]
N = len(FS)
print(f"交付谱 {N} 份")

ut = src = 0
kw = Counter(); kw_hit = Counter()
KW = {"儿歌": r"儿歌|童谣", "动画": r"动画|卡通|主题曲.*动画", "电视剧": r"电视剧|连续剧|央视|剧集",
      "电影": r"电影|影片|插曲|片尾|片头", "主题曲": r"主题曲|主题歌|片头曲", "粤语": r"粤语|广东话",
      "钢琴": r"钢琴", "吉他": r"吉他|六线谱", "双谱": r"双谱|线谱", "合唱": r"合唱|重唱|齐唱",
      "独奏": r"独奏|指弹", "民歌": r"民歌|民谣", "进行曲": r"进行曲|军歌|战歌", "简谱": r"简谱",
      "器乐": r"古筝|二胡|琵琶|笛|葫芦丝|萨克斯|提琴|手风琴|电子琴"}
srcs = Counter()
for f in FS:
    t = io.open(f, encoding="utf-8", errors="replace").read()
    m = re.search(r"(?m)^usertag=(.*)$", t);  ut += bool(m and m.group(1).strip())
    m = re.search(r"(?m)^source=(.*)$", t)
    if m: srcs[m.group(1).strip().split("-")[0]] += 1; src += bool(m.group(1).strip())
    ti = re.search(r"(?m)^title=(.*)$", t)
    ti = ti.group(1) if ti else ""
    for k, rx in KW.items():
        if re.search(rx, ti): kw_hit[k] += 1
print(f"  usertag 非空: {ut}/{N} = {ut/N*100:.1f}%   source= 非空: {src}/{N} = {src/N*100:.1f}%")
print(f"  source 分布: {dict(srcs)}")
print("\n  曲名里能读出的类别(命中数/占比):")
for k, v in kw_hit.most_common():
    print(f"     {k:<8} {v:>5} = {v/N*100:>5.1f}%")
# 爬取批次可推断的歌手/分类
arts = {}
for line in io.open("train-work/jianpujia_artists.tsv", encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if len(c) == 2: arts["jianpujia-art" + c[1]] = c[0]
bat = Counter()
for f in FS:
    for g in glob.glob("images-prep/*/" + glob.escape(os.path.basename(f)[:-4])):
        bat[os.path.basename(os.path.dirname(g))] += 1
        break
named = sum(v for k, v in bat.items() if k in arts)
print(f"\n  谱目录所属爬取批次 {len(bat)} 个; 其中能直接对应到歌手页的批次覆盖 {named}/{N} = {named/N*100:.1f}%")
for k, v in bat.most_common(8):
    print(f"     {k:<22} {v:>5}   {arts.get(k,'')}")
