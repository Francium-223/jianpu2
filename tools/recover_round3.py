# -*- coding: utf-8 -*-
"""抢救 fix_names_round3.py 的误伤: 它用模糊包含匹配, 把 25 条改错了。

被误伤的 21 条是原始名只有一两个字的正常歌(《家》《爱》《你》) -> 现在错成了
`藏在浓雾里的朴家人` / `总有爱`。**正确的旧值在 scores-prev 里** —— 那是重建前
刚移走的上一版 scores, 每份都有 `title=`; 按 `source=<站>-<id>` 就能对回目录名。
(教训: 改名字的脚本必须**精确匹配目录名**, 不能拿原始名做包含匹配 ✗)

真正要改的只有 4 条(小小/啊草原×2/MV_/总有爱), 这里重新精确设置。
用法: py -3.13 tools/recover_round3.py [--dry]
"""
import csv
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DRY = "--dry" in sys.argv
CLEAN = "train-work/title_clean.tsv"

# ① 从 scores-prev 建 "站点-id -> title" 的真值表
prev = {}
for f in glob.glob("jianpu-db-out/scores-prev/*.txt"):
    t = open(f, encoding="utf-8", errors="replace").read(1500)
    ms = re.search(r"^source=(\S+)", t, re.M)
    mt = re.search(r"^title=(.*)$", t, re.M)
    if ms and mt:
        prev[ms.group(1)] = mt.group(1).strip()
print(f"scores-prev 里读到 {len(prev)} 条 (站点-id -> title)")

# ② 精确的第三轮修正(键 = 完整目录名)
EXACT = {
    "MV_藏在浓雾里的朴家人__qupu123-322905": "藏在浓雾里的朴家人",
    "总有爱国语版-一辈子陪你走__jianpucn-273294": "总有爱",
    "小小周杰伦词方文山曲小小周杰伦词_方文山曲简谱__jianpujia-406223": "小小",
    "啊，草原李良词李炫春曲啊，草原李良词_李炫春曲简谱_枫桥__jianpujia-408999": "啊，草原",
    "啊，草原李良词李炫春曲啊，草原李良词_李炫春曲简谱_枫桥演唱_李良_李炫春词曲__jianpujia-406224": "啊，草原",
}

rows = {}
with open(CLEAN, encoding="utf-8") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        rows[r["目录名"]] = dict(r)

restored, fixed, kept = 0, 0, 0
for d, r in rows.items():
    if r.get("原文输出") != "round3-manual":
        continue
    if d in EXACT:
        r["模型曲名"] = EXACT[d]
        r["原文输出"] = "round3-manual-exact"
        fixed += 1
        print(f"  保留修正 {r['原始名'][:36]:<38} -> {EXACT[d]}")
        continue
    # 误伤: 还原成 scores-prev 里的真实 title
    m = re.search(r"__([a-z0-9]+-\d+)$", d)
    old = prev.get(m.group(1)) if m else None
    if old:
        r["模型曲名"] = old
        r["有变化"] = "1" if old != r.get("原始名") else "0"
        r["原文输出"] = "recovered"
        restored += 1
        print(f"  还原 {r['原始名'][:24]:<26} -> {old}")
    else:
        r["原文输出"] = "recovered-unknown"
        kept += 1
        print(f"  [warn] 找不到旧 title, 保持: {d[:40]} -> {r['模型曲名']}")
print(f"\n精确修正 {fixed} 条, 还原 {restored} 条, 找不到旧值 {kept} 条")
if DRY:
    sys.exit(0)
with open(CLEAN, "w", encoding="utf-8") as f:
    f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
    for r in rows.values():
        f.write("\t".join(str(r.get(c, "")).replace("\t", " ") for c in
                          ("目录名", "原始名", "模型曲名", "有变化", "原文输出")) + "\n")
print(f"-> {CLEAN}")
