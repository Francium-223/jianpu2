# -*- coding: utf-8 -*-
"""盘点语料库与转写进度。"""
import glob, json, os, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

dirs = set(os.path.dirname(f) for f in glob.glob("images-prep/*/*/*.jpg"))
done = set(os.path.splitext(os.path.basename(f))[0] for f in glob.glob("batch-out/*.txt"))
ranked = []
if os.path.exists("rank-out/ranked.jsonl"):
    ranked = [json.loads(l) for l in open("rank-out/ranked.jsonl", encoding="utf-8")]

print(f"谱图目录总数:   {len(dirs)}")
print(f"已转写:         {len(done)}")
print(f"剩余可转:       {len(dirs) - len(done)}")
print(f"已有热度排序:   {len(ranked)} 首")
if ranked:
    print("  热度 Top5:")
    for r in ranked[:5]:
        print(f"    {r['play']:>9}  {r['query'][:24]}")
# 按来源统计
src = {}
for d in dirs:
    s = d.split(os.sep)[1] if os.sep in d else d
    src[s] = src.get(s, 0) + 1
print("按来源:", src)
