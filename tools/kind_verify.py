# -*- coding: utf-8 -*-
"""核实关键样本的分类结果。"""
import csv, sys
sys.stdout.reconfigure(encoding="utf-8")
rows = {r["dir"]: r for r in csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t")}
tests = [
    ("去看拉萨河__qupu123-395689", "纯(密集)"),
    ("红星歌简谱___传唱红星歌_重走红军路__jianpujia-15449", "纯"),
    ("K歌之王__jianpucn-40413", "纯"),
    ("十年 歌曲类 简谱__jianpucn-115130", "纯"),
    ("爱情转移(富士山下)__jianpucn-118124", "吉他"),
    ("第一次__jianpucn-87448", "吉他"),
    ("最佳损友__jianpucn-456171", "吉他"),
    ("夜空中最亮的星（五线谱）__qupu123-333873", "五线谱"),
    ("童话总谱__jianpucn-102669", "总谱"),
]
for t, kind in tests:
    r = rows.get(t)
    tag = "?" if not r else ("纯" if r["pure"] == "1" else "非纯")
    nl = r["nline"] if r else "-"
    print(f"  {tag:4s} nline={nl:>4}  期望[{kind:6s}]  {t[:42]}")
