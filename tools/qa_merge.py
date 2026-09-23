# -*- coding: utf-8 -*-
"""QA: 检查版本择优的归并质量(找被并成大组的, 看有没有误并)。不 import pick_best
(那会触发它整段执行), 直接复制 norm_title。"""
import csv, os, re, sys, collections
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

def norm_title(d):
    t = re.sub(r"__(qupu123|jianpujia|jianpucn|qpcxw|gita)-\d+$", "", d)
    def _br(m):
        inner = m.group(1)
        if re.search(r"[词曲唱]|作词|作曲|演唱|原唱|佚名|词_|曲_", inner):
            return "(" + inner + ")"
        return ""
    t = re.sub(r"[（(【\[](.*?)[)）】\]]", _br, t)
    t = re.sub(r"[（(【\[].*$", "", t)
    t = re.sub(r"(简谱|钢琴谱|钢琴|吉他谱|吉他|正谱|双谱|总谱|弹唱谱|指弹谱|尤克里里谱|五线谱|歌词|伴奏谱|"
               r"原版编配|指法|C调|G调|F调|D调|A调|E调|B调|合唱谱|独奏|弹唱|扫描版|不同版本)", "", t)
    t = re.sub(r"[\s_·.,，。、:：;；!！?？'\"“”‘’/\\|+*#@&$%^~`<>\[\]{}]+", "", t)
    return t.lower().strip()

rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
groups = collections.defaultdict(list)
for r in rows:
    k = norm_title(r["dir"])
    if len(k) >= 2:
        groups[k].append(r["dir"])

big = sorted(((len(v), k, v) for k, v in groups.items()), reverse=True)
print(f"共 {len(groups)} 组; 组内 >=6 版的有 {sum(1 for n,_,_ in big if n>=6)} 组")
print("\n最大的 10 组:")
for n, k, v in big[:10]:
    print(f"  [{n:3d} 版] '{k[:30]}'")
    for x in v[:3]:
        print(f"        {x[:58]}")
print("\n检查: 归并名里还带括号(被保留的区分信息)的组数:",
      sum(1 for _, k, _ in big if "(" in k))
